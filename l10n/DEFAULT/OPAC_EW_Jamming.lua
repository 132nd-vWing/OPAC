-- ============================================================================
-- 132nd Virtual Wing - OPAC EW / SRS JAMMING
--
-- Requires:
--   HoundTTS
--   SRS
--
-- Behaviour:
--   * Starts when THIS SCRIPT is loaded by a DCS trigger
--   * Repeats every 20 minutes indefinitely
--   * Three independent spot jammers
--   * 237.000 / 238.000 / 239.000 MHz AM
--   * Each jammer transmits 13 min / 20 min in two blocks
--   * Sender position follows the actual DCS vehicle
--   * Jamming stops immediately when the vehicle is destroyed
--   * Terrain LOS is handled by SRS
--
-- Recommended SRS:
--   Secure Coalition Radios = OFF
--   Line of Sight          = ON
--   Distance Limit         = OFF   (for pure terrain LOS behaviour)
-- ============================================================================

do

    --------------------------------------------------------------------------
    -- CONFIG
    --------------------------------------------------------------------------

    local CONFIG = {
        cycleTime = 20 * 60,       -- 1200 sec

        modulation = "AM",

        -- HoundTTS "jam" noise is specifically designed for jamming.
        noiseType = "jam",

        -- Audio masking level. This is NOT RF transmitter power.
        -- Tune after multiplayer testing if required.
        volume = 0.85,

        -- Exact spot jamming only.
        -- 0 disables adjacent-channel spectral spreading.
        spreadKhz = 0,

        stepKhz = 25,

        -- Update moving jammer position / destruction state twice per second.
        trackingInterval = 0.5,

        -- Small antenna/mast offset above the DCS unit's reported position.
        -- Helps avoid placing the SRS radio effectively at terrain surface.
        antennaHeightMeters = 5,

        -- Small scheduler delay so "00:00" starts immediately after script load.
        startupDelay = 0.10,
    }


    --------------------------------------------------------------------------
    -- JAMMER DEFINITIONS
    --------------------------------------------------------------------------

    local JAMMERS = {

        {
            unitName = "1C_EW_Jammer_platoon1-1",
            frequency = 235.750,

            blocks = {
                -- 00:00 -> 07:00
                { start =   0, duration = 420 },

                -- 11:30 -> 17:30
                { start = 690, duration = 360 },
            },

            session = nil,
        },


        {
            unitName = "1C_EW_Jammer_platoon2-1",
            frequency = 231.750,

            blocks = {
                -- 01:15 -> 07:45
                { start =  75, duration = 390 },

                -- 09:45 -> 16:15
                { start = 585, duration = 390 },
            },

            session = nil,
        },


        {
            unitName = "1C_EW_Jammer_platoon3-1",
            frequency = 229.000,

            blocks = {
                -- 03:00 -> 09:00
                { start = 180, duration = 360 },

                -- 12:00 -> 19:00
                { start = 720, duration = 420 },
            },

            session = nil,
        },
    }


    --------------------------------------------------------------------------
    -- LOGGING
    --------------------------------------------------------------------------

    local function log(text)
        env.info("[132ND EW] " .. tostring(text))
    end

    local function warning(text)
        env.warning("[132ND EW] " .. tostring(text))
    end

    local function errorLog(text)
        env.error("[132ND EW] " .. tostring(text))
    end


    --------------------------------------------------------------------------
    -- HOUNDTTS VALIDATION
    --------------------------------------------------------------------------

    if not HoundTTS then
        errorLog("HoundTTS is not loaded. EW jamming script aborted.")
        return
    end

    if type(HoundTTS.TransmitNoise) ~= "function" then
        errorLog("HoundTTS.TransmitNoise() not available.")
        return
    end

    if type(HoundTTS.UpdateSession) ~= "function" then
        errorLog("HoundTTS.UpdateSession() not available.")
        return
    end

    if type(HoundTTS.KillSession) ~= "function" then
        errorLog("HoundTTS.KillSession() not available.")
        return
    end


    --------------------------------------------------------------------------
    -- GLOBAL STATE / SAFE RELOAD
    --
    -- If the trigger accidentally loads this script twice, the old scheduler
    -- is invalidated and active sessions are killed before restarting.
    --------------------------------------------------------------------------

    _G.OPAC_EW_JAMMING_STATE = _G.OPAC_EW_JAMMING_STATE or {}

    local STATE = _G.OPAC_EW_JAMMING_STATE

    STATE.generation = (STATE.generation or 0) + 1

    local GENERATION = STATE.generation


    if STATE.sessions then

        for _, sessionId in pairs(STATE.sessions) do

            if sessionId then
                pcall(
                    HoundTTS.KillSession,
                    sessionId
                )
            end
        end
    end

    STATE.sessions = {}


    --------------------------------------------------------------------------
    -- HELPERS
    --------------------------------------------------------------------------

    local function unitIsAlive(unit)

        if not unit then
            return false
        end

        local okExist, exists = pcall(
            function()
                return unit:isExist()
            end
        )

        if not okExist or not exists then
            return false
        end


        local okLife, life = pcall(
            function()
                return unit:getLife()
            end
        )

        if not okLife or not life or life <= 0 then
            return false
        end


        return true
    end


    local function getUnitPoint(unit)

        local ok, point = pcall(
            function()
                return unit:getPoint()
            end
        )

        if not ok or not point then
            return nil
        end


        -- Copy the Vec3 instead of modifying DCS' returned table.
        return {
            x = point.x,
            y = point.y + CONFIG.antennaHeightMeters,
            z = point.z,
        }
    end


    local function getUnitCoalition(unit)

        local ok, side = pcall(
            function()
                return unit:getCoalition()
            end
        )

        if ok and side then
            return side
        end

        -- Neutral/spectator fallback.
        return 0
    end


    --------------------------------------------------------------------------
    -- STOP ACTIVE JAMMER
    --------------------------------------------------------------------------

    local function stopJammer(jammer, reason)

        if not jammer.session then
            return
        end


        local sessionId = jammer.session

        jammer.session = nil
        STATE.sessions[jammer.unitName] = nil


        pcall(
            HoundTTS.KillSession,
            sessionId
        )


        log(
            string.format(
                "%s %.3f MHz stopped%s",
                jammer.unitName,
                jammer.frequency,
                reason and (" - " .. reason) or ""
            )
        )
    end


    --------------------------------------------------------------------------
    -- LIVE POSITION / DESTRUCTION TRACKING
    --------------------------------------------------------------------------

    local function trackJammer(args, scheduledTime)

        -- Script was loaded again. Kill this old scheduler.
        if STATE.generation ~= args.generation then
            return nil
        end


        local jammer = args.jammer
        local sessionId = args.sessionId


        -- Session was replaced or stopped.
        if jammer.session ~= sessionId then
            return nil
        end


        local unit = Unit.getByName(jammer.unitName)


        -- Physical jammer destroyed/despawned.
        if not unitIsAlive(unit) then

            stopJammer(
                jammer,
                "vehicle destroyed"
            )

            return nil
        end


        local point = getUnitPoint(unit)

        if not point then

            stopJammer(
                jammer,
                "could not obtain unit position"
            )

            return nil
        end


        local ok, alive = pcall(
            HoundTTS.UpdateSession,
            sessionId,
            {
                point = point
            }
        )


        -- HoundTTS reports false/nil after the timed block finishes.
        if not ok or alive ~= true then

            if jammer.session == sessionId then
                jammer.session = nil
                STATE.sessions[jammer.unitName] = nil
            end

            return nil
        end


        return scheduledTime + CONFIG.trackingInterval
    end


    --------------------------------------------------------------------------
    -- START ONE JAMMING BLOCK
    --------------------------------------------------------------------------

    local function startJamming(jammer, block)

        if STATE.generation ~= GENERATION then
            return
        end


        local unit = Unit.getByName(jammer.unitName)


        if not unitIsAlive(unit) then

            warning(
                string.format(
                    "%s unavailable/dead - scheduled %.3f MHz block skipped.",
                    jammer.unitName,
                    jammer.frequency
                )
            )

            return
        end


        -- Defensive cleanup. Blocks should never overlap.
        if jammer.session then
            stopJammer(
                jammer,
                "replacing unexpected active session"
            )
        end


        local point = getUnitPoint(unit)

        if not point then

            errorLog(
                jammer.unitName ..
                ": unable to obtain transmitter position."
            )

            return
        end


        -- Use the actual DCS coalition of the jammer vehicle.
        --
        -- Because Secure Coalition Radios is OFF on your SRS server,
        -- players from all coalitions can hear this transmission.
        local senderCoalition = getUnitCoalition(unit)


        local ok, sessionId = pcall(

            HoundTTS.TransmitNoise,

            {
                transmitter = "srs",

                freqs = string.format(
                    "%.3f",
                    jammer.frequency
                ),

                modulations = CONFIG.modulation,

                coalition = senderCoalition,

                -- Do not reveal actual DCS unit name in SRS UI.
                name = "UNKNOWN",

                point = point,

                encrypt = false,
            },

            {
                noiseType = CONFIG.noiseType,

                volume = CONFIG.volume,

                duration = block.duration,

                -- Exact spot jamming:
                spreadKhz = CONFIG.spreadKhz,

                stepKhz = CONFIG.stepKhz,
            }
        )


        if not ok or not sessionId then

            errorLog(
                string.format(
                    "%s failed to start jamming on %.3f MHz.",
                    jammer.unitName,
                    jammer.frequency
                )
            )

            return
        end


        jammer.session = sessionId

        STATE.sessions[jammer.unitName] = sessionId


        log(
            string.format(
                "%s START %.3f MHz AM - duration %d sec",
                jammer.unitName,
                jammer.frequency,
                block.duration
            )
        )


        -- Continuously update physical transmitter position and check life.
        timer.scheduleFunction(
            trackJammer,

            {
                jammer = jammer,
                sessionId = sessionId,
                generation = GENERATION,
            },

            timer.getTime() + CONFIG.trackingInterval
        )
    end


    --------------------------------------------------------------------------
    -- REPEATING 20-MINUTE BLOCK SCHEDULER
    --------------------------------------------------------------------------

    local function scheduledBlock(args, scheduledTime)

        if STATE.generation ~= args.generation then
            return nil
        end


        startJamming(
            args.jammer,
            args.block
        )


        -- Repeat at exactly the same point next 20-minute cycle.
        return scheduledTime + CONFIG.cycleTime
    end


    --------------------------------------------------------------------------
    -- VALIDATE UNIT NAMES / SCHEDULE
    --------------------------------------------------------------------------

    for _, jammer in ipairs(JAMMERS) do

        local total = 0

        for _, block in ipairs(jammer.blocks) do

            total = total + block.duration

            if block.start < 0 then
                errorLog(jammer.unitName .. ": invalid negative block start.")
            end

            if block.start + block.duration > CONFIG.cycleTime then
                errorLog(jammer.unitName .. ": block exceeds 20-minute cycle.")
            end
        end


        if total ~= 780 then

            errorLog(
                string.format(
                    "%s has %d sec total TX; expected 780 sec.",
                    jammer.unitName,
                    total
                )
            )
        end


        local unit = Unit.getByName(jammer.unitName)

        if not unit then

            warning(
                "Unit not found at script load: " ..
                jammer.unitName
            )

        else

            log(
                "Validated unit: " ..
                jammer.unitName
            )
        end
    end


    --------------------------------------------------------------------------
    -- START THE CLOCK
    --
    -- THIS is time 00:00 for the jammer pattern.
    --------------------------------------------------------------------------

    local cycleZero =
        timer.getTime() + CONFIG.startupDelay


    for _, jammer in ipairs(JAMMERS) do

        for _, block in ipairs(jammer.blocks) do

            timer.scheduleFunction(
                scheduledBlock,

                {
                    jammer = jammer,
                    block = block,
                    generation = GENERATION,
                },

                cycleZero + block.start
            )
        end
    end


    log(
        "EW jamming ENABLED. " ..
        "20-minute repeating pattern begins now."
    )

end
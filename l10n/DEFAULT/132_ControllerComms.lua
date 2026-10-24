-- 132_ControllerComms.lua
-- DCS multiplayer controller comms helper
-- Voice: HoundTTS -> SRS
-- Optional text: LotAtC mission Lua link
--
-- Load once at mission start with Mission Editor:
--   TRIGGER: MISSION START -> DO SCRIPT FILE -> 132_ControllerComms.lua
--
-- Then call from any trigger:
--   CTRL:Routine("Magic, intelligence update. Unknown aircraft detected.")
--   CTRL:Priority("Magic, priority. Hostile aircraft approaching sector Alpha.")
--   CTRL:Emergency("Magic, emergency. Scramble alert.")
--
-- Requires HoundTTS on the DCS server for voice transmissions.
-- LotAtC text is optional and disabled by default.

CTRL = CTRL or {}

CTRL.VERSION = "1.0.0"

----------------------------------------------------------------
-- CONFIGURATION
----------------------------------------------------------------
CTRL.config = {
    -- SRS radio
    FREQUENCIES      = "237.000", -- MHz. Multiple: "251.000,305.000"
    MODULATIONS      = "AM",      -- Match count if multiple: "AM,AM"
    COALITION_ID     = 2,         -- 0=spectator, 1=red, 2=blue
    TRANSMITTER_NAME = "BLUE C2",

    -- HoundTTS provider
    PROVIDER          = "piper",
    VOICE             = "en_US-lessac-low",
    CULTURE           = "en-US",
    SPEED             = 0.90,
    VOLUME            = 1.00,

    -- Usually leave nil and configure Saved Games\<DCS>\Config\HoundTTS.lua.
    -- Set here only if you specifically want mission-level overrides.
    SRS_HOST          = nil,      -- e.g. "127.0.0.1" or "192.168.1.20"
    SRS_PORT          = nil,      -- usually 5002

    -- SRS encryption, if used by your controller net
    ENCRYPT           = false,
    ENC_KEY           = 0,

    -- Features
    ENABLE_VOICE      = true,

    -- Optional LotAtC text copy.
    -- Requires LotAtC Mission Lua integration on the server.
    ENABLE_LOTATC_TEXT = true,
    LOTATC_COALITION   = "blue",  -- "blue" or "red"
    LOTATC_ADD_PRIORITY_PREFIX = true,

    -- Voice queue
    QUEUE_GAP          = 1.0,     -- seconds between transmissions
    START_DELAY        = 0.10,    -- scheduler delay after first queue item

    -- Logging
    LOG_PREFIX         = "[132 ControllerComms]"
}

----------------------------------------------------------------
-- PRIORITIES
-- Priority changes the order of messages waiting in the queue.
-- It does NOT interrupt a transmission already on air.
----------------------------------------------------------------
CTRL.priorities = {
    ROUTINE   = 10,
    PRIORITY  = 50,
    EMERGENCY = 100
}

CTRL._queue = CTRL._queue or {}
CTRL._busy = false
CTRL._seq = 0
CTRL._currentSession = nil
CTRL._warnedNoHound = false
CTRL._warnedNoLotAtc = false

----------------------------------------------------------------
-- INTERNAL HELPERS
----------------------------------------------------------------
local function _log(msg)
    if env and env.info then
        env.info(CTRL.config.LOG_PREFIX .. " " .. tostring(msg))
    end
end

local function _warn(msg)
    if env and env.warning then
        env.warning(CTRL.config.LOG_PREFIX .. " " .. tostring(msg))
    elseif env and env.info then
        env.info(CTRL.config.LOG_PREFIX .. " WARNING: " .. tostring(msg))
    end
end

local function _err(msg)
    if env and env.error then
        env.error(CTRL.config.LOG_PREFIX .. " " .. tostring(msg))
    elseif env and env.info then
        env.info(CTRL.config.LOG_PREFIX .. " ERROR: " .. tostring(msg))
    end
end

local function _copyTable(src)
    local dst = {}
    if src then
        for k, v in pairs(src) do
            dst[k] = v
        end
    end
    return dst
end

local function _priorityValue(priority)
    if type(priority) == "number" then
        return priority
    end

    local key = string.upper(tostring(priority or "ROUTINE"))
    return CTRL.priorities[key] or CTRL.priorities.ROUTINE
end

local function _priorityName(priority)
    if type(priority) == "string" then
        local key = string.upper(priority)
        if CTRL.priorities[key] then
            return key
        end
    end

    local value = _priorityValue(priority)
    if value >= CTRL.priorities.EMERGENCY then
        return "EMERGENCY"
    elseif value >= CTRL.priorities.PRIORITY then
        return "PRIORITY"
    end
    return "ROUTINE"
end

function CTRL:_houndAvailable()
    return type(HoundTTS) == "table"
       and type(HoundTTS.Transmit) == "function"
end

function CTRL:_lotAtcAvailable()
    return type(lotatcLink) == "table"
       and type(lotatcLink.sendToControllers) == "function"
end

function CTRL:_sendLotAtcText(text, priority, opts)
    if not self.config.ENABLE_LOTATC_TEXT then
        return false
    end

    if not self:_lotAtcAvailable() then
        if not self._warnedNoLotAtc then
            _warn("LotAtC text enabled, but lotatcLink.sendToControllers is not available. Voice can still work.")
            self._warnedNoLotAtc = true
        end
        return false
    end

    local coalitionName = opts.lotatcCoalition or self.config.LOTATC_COALITION
    local outText = text

    if self.config.LOTATC_ADD_PRIORITY_PREFIX then
        local pName = _priorityName(priority)
        if pName ~= "ROUTINE" then
            outText = "[" .. pName .. "] " .. outText
        end
    end

    local ok, result = pcall(
        lotatcLink.sendToControllers,
        coalitionName,
        outText
    )

    if not ok then
        _err("LotAtC sendToControllers failed: " .. tostring(result))
        return false
    end

    return true
end

function CTRL:_buildTransmissionParams(opts)
    local tx = {
        freqs       = opts.freqs or self.config.FREQUENCIES,
        modulations = opts.modulations or self.config.MODULATIONS,
        coalition   = opts.coalition or self.config.COALITION_ID,
        name        = opts.name or self.config.TRANSMITTER_NAME,
        encrypt     = (opts.encrypt ~= nil) and opts.encrypt or self.config.ENCRYPT,
        encKey      = opts.encKey or self.config.ENC_KEY
    }

    local host = opts.host or self.config.SRS_HOST
    local port = opts.port or self.config.SRS_PORT

    if host and host ~= "" then
        tx.host = host
    end

    if port then
        tx.port = port
    end

    -- Optional physical transmitter position.
    -- opts.unitName = name of a DCS Unit
    -- opts.point    = DCS Vec3
    if opts.point then
        tx.point = opts.point
    elseif opts.unitName and Unit and Unit.getByName then
        local unit = Unit.getByName(opts.unitName)
        if unit then
            local exists = true
            if unit.isExist then
                local ok, result = pcall(unit.isExist, unit)
                exists = ok and result
            end

            if exists then
                tx.dcsObject = unit
            else
                _warn("Transmitter unit does not exist: " .. tostring(opts.unitName))
            end
        else
            _warn("Transmitter unit not found: " .. tostring(opts.unitName))
        end
    end

    return tx
end

function CTRL:_buildProviderParams(opts)
    return {
        provider = opts.provider or self.config.PROVIDER,
        voice    = opts.voice or self.config.VOICE,
        culture  = opts.culture or self.config.CULTURE,
        speed    = opts.speed or self.config.SPEED,
        volume   = opts.volume or self.config.VOLUME
    }
end

function CTRL:_transmitItem(item)
    if not self:_houndAvailable() then
        if not self._warnedNoHound then
            _err("HoundTTS is not available in the mission Lua environment. Check the server installation.")
            self._warnedNoHound = true
        end
        return 0
    end

    local tx = self:_buildTransmissionParams(item.opts)
    local provider = self:_buildProviderParams(item.opts)

    local ok, speechTime, sessionId = pcall(
        HoundTTS.Transmit,
        item.text,
        tx,
        provider
    )

    if not ok then
        _err("HoundTTS.Transmit failed: " .. tostring(speechTime))
        return 0
    end

    self._currentSession = sessionId

    speechTime = tonumber(speechTime)
    if not speechTime and type(HoundTTS.getSpeechTime) == "function" then
        local estimateOk, estimate = pcall(
            HoundTTS.getSpeechTime,
            item.text,
            provider.speed or 1.0,
            false
        )
        if estimateOk then
            speechTime = tonumber(estimate)
        end
    end

    speechTime = speechTime or 2.0

    _log(string.format(
        "TX %s | %.1fs | %s %s | %s",
        item.priorityName,
        speechTime,
        tostring(tx.freqs),
        tostring(tx.modulations),
        item.text
    ))

    return speechTime
end

function CTRL._scheduler(_, scheduledTime)
    if #CTRL._queue == 0 then
        CTRL._busy = false
        CTRL._currentSession = nil
        return nil
    end

    table.sort(CTRL._queue, function(a, b)
        if a.priority == b.priority then
            return a.seq < b.seq
        end
        return a.priority > b.priority
    end)

    local item = table.remove(CTRL._queue, 1)
    local duration = CTRL:_transmitItem(item)

    if duration <= 0 then
        duration = 0.5
    end

    return scheduledTime + duration + CTRL.config.QUEUE_GAP
end

----------------------------------------------------------------
-- PUBLIC API
----------------------------------------------------------------

-- Main function.
--
-- Example:
--   CTRL:Message(
--       "Magic, intelligence update. Two unknown contacts approaching sector Alpha.",
--       "PRIORITY"
--   )
--
-- Optional third parameter:
--   {
--      voiceEnabled = true/false,
--      textEnabled = true/false,
--      freqs = "251.000",
--      modulations = "AM",
--      name = "BLUE C2",
--      coalition = 2,
--      unitName = "BLUE_C2_RADIO",
--      point = someVec3,
--      provider = "piper",
--      voice = "en_US-ryan-low",
--      speed = 1.0,
--      volume = 1.0
--   }
function CTRL:Message(text, priority, options)
    if type(text) ~= "string" or text == "" then
        _warn("CTRL:Message called with empty/non-string text.")
        return false
    end

    local opts = _copyTable(options)
    local pValue = _priorityValue(priority)
    local pName = _priorityName(priority)

    local sendVoice = self.config.ENABLE_VOICE
    if opts.voiceEnabled ~= nil then
        sendVoice = opts.voiceEnabled
    end

    local sendText = self.config.ENABLE_LOTATC_TEXT
    if opts.textEnabled ~= nil then
        sendText = opts.textEnabled
    end

    if sendText then
        self:_sendLotAtcText(text, priority, opts)
    end

    if not sendVoice then
        return true
    end

    self._seq = self._seq + 1

    table.insert(self._queue, {
        text = text,
        priority = pValue,
        priorityName = pName,
        seq = self._seq,
        opts = opts
    })

    if not self._busy then
        self._busy = true

        if timer and timer.scheduleFunction and timer.getTime then
            timer.scheduleFunction(
                self._scheduler,
                nil,
                timer.getTime() + self.config.START_DELAY
            )
        else
            _err("DCS timer API unavailable; cannot start voice queue.")
            self._busy = false
            return false
        end
    end

    return true
end

function CTRL:Routine(text, options)
    return self:Message(text, "ROUTINE", options)
end

function CTRL:Priority(text, options)
    return self:Message(text, "PRIORITY", options)
end

function CTRL:Emergency(text, options)
    return self:Message(text, "EMERGENCY", options)
end

-- Voice only, regardless of LotAtC text configuration.
function CTRL:Voice(text, priority, options)
    local opts = _copyTable(options)
    opts.voiceEnabled = true
    opts.textEnabled = false
    return self:Message(text, priority or "ROUTINE", opts)
end

-- LotAtC text only. Requires ENABLE_LOTATC_TEXT=true and LotAtC link.
function CTRL:Text(text, priority, options)
    local opts = _copyTable(options)
    opts.voiceEnabled = false
    opts.textEnabled = true
    return self:Message(text, priority or "ROUTINE", opts)
end

-- Sends a 440 Hz tone over SRS. Useful before debugging TTS voices.
function CTRL:TestTone(duration)
    if not self:_houndAvailable() or type(HoundTTS.TestTone) ~= "function" then
        _err("HoundTTS.TestTone is unavailable.")
        return false
    end

    local ok, result = pcall(
        HoundTTS.TestTone,
        self.config.FREQUENCIES,
        self.config.MODULATIONS,
        self.config.COALITION_ID,
        duration or 2.0,
        1.0
    )

    if not ok then
        _err("HoundTTS.TestTone failed: " .. tostring(result))
        return false
    end

    _log("Test tone transmitted.")
    return true
end

-- Remove messages not yet transmitted.
function CTRL:ClearQueue()
    self._queue = {}
    _log("Voice queue cleared.")
end

-- Stops the current HoundTTS session if possible.
-- Note: the queue scheduler will still wait until the current time slot expires.
function CTRL:KillCurrent()
    if not self._currentSession then
        return false
    end

    if self:_houndAvailable() and type(HoundTTS.KillSession) == "function" then
        local ok, result = pcall(HoundTTS.KillSession, self._currentSession)
        if ok then
            self._currentSession = nil
            return result == true
        end
    end

    return false
end

function CTRL:Status()
    local hound = self:_houndAvailable() and "YES" or "NO"
    local lotatc = self:_lotAtcAvailable() and "YES" or "NO"

    _log(
        "v" .. self.VERSION
        .. " | HoundTTS=" .. hound
        .. " | LotAtCLink=" .. lotatc
        .. " | Freq=" .. tostring(self.config.FREQUENCIES)
        .. " " .. tostring(self.config.MODULATIONS)
    )

    return {
        version = self.VERSION,
        houndTTS = (hound == "YES"),
        lotAtcLink = (lotatc == "YES"),
        queueLength = #self._queue
    }
end

_log("Loaded v" .. CTRL.VERSION .. ". Use CTRL:TestTone() and CTRL:Status() for testing.")

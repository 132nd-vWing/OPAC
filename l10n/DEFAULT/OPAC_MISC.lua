_SETTINGS:SetPlayerMenuOff()

---important: the MessageToAll function was removed from Moose, we add it back here, else all other scripts will break. 
function MessageToAll( MsgText, MsgTime, MsgName )
  -- trace.f()
  MESSAGE:New( MsgText, MsgTime, "Message" ):ToCoalition( coalition.side.RED ):ToCoalition( coalition.side.BLUE )
end
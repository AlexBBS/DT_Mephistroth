-- sound.lua (ключи строго lower-case)

DT_MEPH = DT_MEPH or {}
DT_MEPH.sounds = DT_MEPH.sounds or {}

DT_MEPH.sounds["stoyat"] = "Interface\\AddOns\\DT_Mephistroth\\Sounds\\stoyat.wav"
DT_MEPH.sounds["begi"]   = "Interface\\AddOns\\DT_Mephistroth\\Sounds\\begi.wav"
DT_MEPH.sounds["krasava"]   = "Interface\\AddOns\\DT_Mephistroth\\Sounds\\krasava.wav"

local FALLBACK = "Sound\\Interface\\RaidWarning.wav"

function DT_MEPH:Sound(key)
    key = string.lower(tostring(key or ""))
    local path = self.sounds[key]


    if type(path) == "string" then
        PlaySoundFile(path)
    else
        PlaySoundFile(FALLBACK)
    end
end

SLASH_DTMSOUND1 = "/dtmsound"
SlashCmdList["DTMSOUND"] = function(msg)
    msg = string.lower(tostring(msg or ""))
    if msg == "" then msg = "stoyat" end
    DT_MEPH:Sound(msg)
end

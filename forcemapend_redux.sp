#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <cstrike>
#include <smutils>
#include <mapchooser_redux>

#undef REQUIRE_PLUGIN
#include <fys.pupd>

public Plugin myinfo =
{
    name        = "ForceMapEnd - Redux",
    author      = "Kyle",
    description = "Force round end for KZ/BHop/Surf server",
    version     = MCR_VERSION,
    url         = "https://www.kxnrl.com"
};

//credits: https://forums.alliedmods.net/showthread.php?t=254830

#define MAXTIME 546

ConVar mp_timelimit;

bool g_pMaps;

// HACK: import native directly
native int Maps_GetTimeLeft();

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    MarkNativeAsOptional("Pupd_CheckPlugin");
    MarkNativeAsOptional("Maps_GetTimeLeft");
    return APLRes_Success;
}

public void OnPluginStart()
{
    SMUtils_SetChatPrefix("[\x02M\x04C\x0CR\x01]");
    SMUtils_SetChatSpaces("   ");
    SMUtils_SetChatConSnd(true);
    SMUtils_SetTextDest(HUD_PRINTCENTER);

    mp_timelimit = FindConVar("mp_timelimit");
}

public void OnAllPluginsLoaded()
{
    g_pMaps = LibraryExists("fys-Maps");
}

public void OnLibraryAdded(const char[] name)
{
    if (strcmp(name, "fys-Maps") == 0)
        g_pMaps = true;
}

public void OnLibraryRemoved(const char[] name)
{
    if (strcmp(name, "fys-Maps") == 0)
        g_pMaps = false;
}

public void Pupd_OnCheckAllPlugins()
{
    Pupd_CheckPlugin(false, "https://build.kxnrl.com/updater/MCR/");
}

public void OnMapStart()
{
    RequestFrame(Frame_TimeLeft, _);
    CreateTimer(1.0, Timer_Tick, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public void OnMapTimeLeftChanged()
{
    RequestFrame(Frame_TimeLeft, _);
}

void Frame_TimeLeft(any unuse)
{
    int timeleft = GetTimeLeft();

    if(timeleft < 1) return; 
    if(timeleft > 32767)
    {
        RequestFrame(SetMapTime, MAXTIME);
        return;
    }

    GameRules_SetProp("m_iRoundTime", timeleft-1, 4, 0, true);
}

void SetMapTime(int time)
{
    mp_timelimit.SetInt(time, true, true);
}

public Action Timer_Tick(Handle timer)
{
    if (mp_timelimit.IntValue <= 0)
    {
        mp_timelimit.SetInt(60, true, true);
        return Plugin_Continue;
    }

    int timeleft = GetTimeLeft();

    switch (timeleft)
    {
        case 1800:   ChatAll("{lightred}Timeleft: 30 minutes");
        case 1200:   ChatAll("{lightred}Timeleft: 20 minutes");
        case 600:    ChatAll("{lightred}Timeleft: 10 minutes");
        case 300:    ChatAll("{lightred}Timeleft: 5 minutes");
        case 120:    ChatAll("{lightred}Timeleft: 2 minutes");
        case 60:     ChatAll("{lightred}Timeleft: 60 seconds");
        case 30:     ChatAll("{lightred}Timeleft: 30 seconds");
        case 15:     ChatAll("{lightred}Timeleft: 15 seconds");
        case  3:     ChatAll("{lightred}Timeleft: 3..");
        case  2:     ChatAll("{lightred}Timeleft: 2..");
        case  1:     ChatAll("{lightred}Timeleft: 1..");
    }

    if(timeleft <= 0)
        CS_TerminateRound(0.0, CSRoundEnd_Draw, true);

    return Plugin_Continue;
}

public Action CS_OnTerminateRound(float &delay, CSRoundEndReason &reason)
{
    return Plugin_Handled;
}

stock int GetTimeLeft()
{
    if (g_pMaps)
        return Maps_GetTimeLeft();

    int timeLeft;
    return GetMapTimeLeft(timeLeft) ? timeLeft : 0;
}
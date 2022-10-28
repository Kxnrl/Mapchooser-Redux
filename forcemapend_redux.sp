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

#define MAXTIME 546

ConVar mp_timelimit;
ConVar mp_maxrounds;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    MarkNativeAsOptional("Pupd_CheckPlugin");
    return APLRes_Success;
}

public void OnPluginStart()
{
    if (GetEngineVersion() != Engine_CSGO)
        SetFailState("Engine not support!");

    SMUtils_SetChatPrefix("[\x02M\x04C\x0CR\x01]");
    SMUtils_SetChatSpaces("   ");
    SMUtils_SetChatConSnd(true);
    SMUtils_SetTextDest(HUD_PRINTCENTER);

    mp_timelimit = FindConVar("mp_timelimit");
    mp_maxrounds = FindConVar("mp_maxrounds");
    mp_maxrounds.IntValue = 0;
    mp_maxrounds.AddChangeHook(OnLock);
}

void OnLock(ConVar cvar, const char[] unuse1, const char[] unuse2)
{
    cvar.IntValue = 0;
}

public void Pupd_OnCheckAllPlugins()
{
    Pupd_CheckPlugin(false, "https://build.kxnrl.com/updater/MCR/");
}

public void OnConfigsExecuted()
{
    RequestFrame(Frame_TimeLeft);
    CreateTimer(1.0, Timer_Tick, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public void OnMapTimeLeftChanged()
{
    RequestFrame(Frame_TimeLeft);
}

void Frame_TimeLeft()
{
    int timeleft = GetTimeLeft();

    if(timeleft < 1) return; 
    if(timeleft > 32767)
    {
        RequestFrame(SetMapTime, MAXTIME);
    }

    RequestFrame(UpdateHudTime);
}

void UpdateHudTime()
{
    int realTime = GetRoundElapsed() + GetTimeLeft();
    int m_iRoundTime = GameRules_GetProp("m_iRoundTime");
    if (m_iRoundTime != realTime)
    {
        GameRules_SetProp("m_iRoundTime", realTime, 4, 0, true);
        PrintToServer("[MCR]  Adjust m_iRoundTime = %d from %d", realTime, m_iRoundTime);
    }
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
        CS_TerminateRound(10.0, CSRoundEnd_Draw, true);
    else
        UpdateHudTime();

    return Plugin_Continue;
}

public Action CS_OnTerminateRound(float &delay, CSRoundEndReason &reason)
{
    if (reason == CSRoundEnd_GameStart && FindPluginByFile("SurfTimer") != null)
    {
        LogMessage("Fix SurfTimer restart game...");
        CreateTimer(1.0, FixSurftimerShit, _, TIMER_FLAG_NO_MAPCHANGE);
    }

    return Plugin_Handled;
}

Action FixSurftimerShit(Handle timer)
{
    CS_TerminateRound(1.0, CSRoundEnd_GameStart, true);
    return Plugin_Stop;
}

stock int GetTimeLeft()
{
    float m_flGameStartTime = GameRules_GetPropFloat("m_flGameStartTime");
    float flTimeLeft =  ( m_flGameStartTime + mp_timelimit.IntValue * 60.0 ) - GetGameTime();
    if (flTimeLeft < 0.0)
        flTimeLeft = 0.0;
    return RoundToFloor(flTimeLeft);
}

stock int GetRoundElapsed()
{
    int iTimeLeft = RoundToFloor(GetGameTime() - GameRules_GetPropFloat("m_fRoundStartTime"));
    return iTimeLeft > 0 ? iTimeLeft : 0;
}
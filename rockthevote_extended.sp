#include <mapchooser_extended>
#include <nextmap>
#include <cstrike>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <KZTimer>
#include <cg_core>

#pragma newdecls required

bool g_bAllowRTV;
bool g_bInChange;
bool g_bKzTimer;
bool g_bVoted[MAXPLAYERS+1];

public Plugin myinfo =
{
    name        = "Rock The Vote Redux",
    author      = "Kyle",
    description = "Provides RTV Map Voting",
    version     = MCE_VERSION,
    url         = "http://steamcommunity.com/id/_xQy_/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    MarkNativeAsOptional("KZTimer_GetSkillGroup");
    MarkNativeAsOptional("CG_ClientIsVIP");
    return APLRes_Success;
}

public void OnPluginStart()
{
    LoadTranslations("common.phrases");
    LoadTranslations("rockthevote.phrases");
    LoadTranslations("basevotes.phrases");

    RegAdminCmd("sm_forcertv", Command_ForceRTV, ADMFLAG_CHANGEMAP, "Force an RTV vote");
    RegAdminCmd("mce_forcertv", Command_ForceRTV, ADMFLAG_CHANGEMAP, "Force an RTV vote");
}

public void OnMapStart()
{
    g_bInChange = false;
    g_bKzTimer = false; 
}

public void OnMapEnd()
{
    g_bAllowRTV = false;
}

public void OnConfigsExecuted()
{
    g_bAllowRTV = false;
    CreateTimer(30.0, Timer_DelayRTV, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientConnected(int client)
{
    g_bVoted[client] = false;
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
    if(!client || !IsAllowClient(client))
        return;
    
    if(!StrEqual(sArgs, "!rtv", false) && !StrEqual(sArgs, "rtv", false))
        return;

    AttemptRTV(client);
}

void AttemptRTV(int client)
{
    if(!g_bAllowRTV)
    {
        PrintToChat(client, "[\x04MCE\x01]  %t", "RTV Not Allowed");
        return;
    }

    if(!CanMapChooserStartVote())
    {
        PrintToChat(client, "[\x04MCE\x01]  %t", "RTV Started");
        return;
    }

    if(g_bVoted[client])
    {
        RTV_CheckStatus(client, true);
        return;
    }

    g_bVoted[client] = true;

    if(RTV_CheckStatus(client, true)) 
        StartRTV();
}

public Action Timer_DelayRTV(Handle timer)
{
    g_bAllowRTV = true;
    if(GetFeatureStatus(FeatureType_Native, "KZTimer_GetSkillGroup") == FeatureStatus_Available)
        g_bKzTimer = true;
}

void StartRTV()
{
    if(g_bInChange)
        return;    

    if(HasEndOfMapVoteFinished())
    {
        char map[128];
        if(GetNextMap(map, 128))
        {
            PrintToChatAll("[\x04MCE\x01]  %t", "Changing Maps", map);
            CreateTimer(10.0, Timer_ChangeMap, _, TIMER_FLAG_NO_MAPCHANGE);
            g_bInChange = true;

            ResetRTV();

            g_bAllowRTV = false;
        }
        return;    
    }

    if(CanMapChooserStartVote())
    {
        InitiateMapChooserVote(MapChange_Instant);
        ResetRTV();

        g_bAllowRTV = false;
        CreateTimer(300.0, Timer_DelayRTV, _, TIMER_FLAG_NO_MAPCHANGE);
    }
}

void ResetRTV()
{
    for(int i = 1; i <= MaxClients+1; i++)
        g_bVoted[i] = false;
}

public Action Timer_ChangeMap(Handle hTimer)
{
    SetConVarInt(FindConVar("mp_halftime"), 0);
    SetConVarInt(FindConVar("mp_timelimit"), 0);
    SetConVarInt(FindConVar("mp_maxrounds"), 0);
    SetConVarInt(FindConVar("mp_roundtime"), 1);

    CS_TerminateRound(12.0, CSRoundEnd_Draw, true);

    if(g_bKzTimer)
    {
        CreateTimer(10.0, Timer_ChangeMapKZ, INVALID_HANDLE, TIMER_FLAG_NO_MAPCHANGE);
        return Plugin_Stop;
    }

    if(FindPluginByFile("zombiereloaded.smx"))
        return Plugin_Stop;

    for(int client = 1; client <= MaxClients; ++client)
    {
        if(!IsClientInGame(client))
            continue;
        
        if(!IsPlayerAlive(client))
            continue;
        
        ForcePlayerSuicide(client);
    }

    return Plugin_Stop;
}

public Action Timer_ChangeMapKZ(Handle hTimer, Handle dp)
{
    PrintToChatAll("debug: Timer_ChangeMapKZ");
    char map[256];
    
    if(dp == INVALID_HANDLE)
    {
        if(!GetNextMap(map, 256))
        {
            LogError("Timer_ChangeMapKZ -> !GetNextMap");
            return Plugin_Stop;    
        }
    }
    else
    {
        ResetPack(dp);
        ReadPackString(dp, map, 256);
    }

    ForceChangeLevel(map, "Map Vote");
    
    return Plugin_Stop;
}

public Action Command_ForceRTV(int client, int args)
{
    if(!client)
        return Plugin_Handled;

    PrintToChatAll("[\x04MCE\x01]  %t", "Initiated Vote Map");

    StartRTV();

    return Plugin_Handled;
}

bool IsAllowClient(int client)
{
    if(!g_bKzTimer)
        return true;

    if(KZTimer_GetSkillGroup(client) >= 2 || IsClientVIP(client))
        return true;

    PrintToChat(client, "[\x04MCE\x01]  \x07你的KZ等级不够,禁止RTV");
    return false;
}

bool RTV_CheckStatus(int client, bool notice)
{
    int need, done;
    GetPlayers(need, done);
    
    if(notice)
    {
        char name[64];
        GetClientName(client, name, 64);
        PrintToChatAll("[\x04MCE\x01]  %t", "RTV Requested", name, done, need);
    }
    
    return (done >= need);
}

void GetPlayers(int &need, int &done)
{
    need = 0;
    done = 0;
    for(int client = 1; client <= MaxClients; client++)
        if(IsClientInGame(client) && !IsFakeClient(client))
        {
            need++;
            if(g_bVoted[client])
                done++;
        }

    need = RoundFloat(need*0.6);    
}

stock bool IsClientVIP(int client)
{
    return LibraryExists("csgogamers") ? CG_ClientIsVIP(client) : CheckCommandAccess(client, "check_isclientvip", ADMFLAG_RESERVATION, false);
}
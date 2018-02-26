#include <mapchooser_redux>
#include <nextmap>
#include <cstrike>
#include <sdktools>

#pragma newdecls required

bool g_bAllowRTV;
bool g_bInChange;
bool g_bVoted[MAXPLAYERS+1];

public Plugin myinfo =
{
    name        = "Rock The Vote Redux",
    author      = "Kyle",
    description = "Provides RTV Map Voting",
    version     = MCR_VERSION,
    url         = "http://steamcommunity.com/id/_xQy_/"
};

public void OnPluginStart()
{
    RegAdminCmd("sm_forcertv", Command_ForceRTV, ADMFLAG_CHANGEMAP, "Force an RTV vote");
}

public void OnMapStart()
{
    g_bInChange = false;
    g_bAllowRTV = false;
    CreateTimer(180.0, Timer_DelayRTV, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_DelayRTV(Handle timer)
{
    g_bAllowRTV = true;
}

public void OnClientConnected(int client)
{
    g_bVoted[client] = false;
}

public void OnClientDisconnect(int client)
{
    g_bVoted[client] = false;
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
    if(!client)
        return;

    if(strcmp(sArgs, "!rtv", false) == 0 || strcmp(sArgs, "rtv", false) == 0)
        AttemptRTV(client);
}

void AttemptRTV(int client)
{
    if(!g_bAllowRTV)
    {
        PrintToChat(client, "[\x04MCR\x01]  当前不允许RTV!");
        return;
    }

    if(!CanMapChooserStartVote())
    {
        PrintToChat(client, "[\x04MCR\x01]  RTV投票已启动!");
        return;
    }

    if(g_bVoted[client])
    {
        RTV_CheckStatus(client, true, true);
        return;
    }

    g_bVoted[client] = true;

    if(RTV_CheckStatus(client, true, false)) 
        StartRTV();
}

void StartRTV()
{
    if(g_bInChange)
        return;
    
    ResetRTV();
    g_bAllowRTV = false;

    if(HasEndOfMapVoteFinished())
    {
        char map[128];
        if(GetNextMap(map, 128))
        {
            g_bInChange = true;
            
            PrintToChatAll("[\x04MCR\x01]  正在更换地图到[\x05%s\x01]", map);
            CreateTimer(10.0, Timer_ChangeMap, _, TIMER_FLAG_NO_MAPCHANGE);
        }

        return;    
    }

    if(CanMapChooserStartVote())
    {
        InitiateMapChooserVote(MapChange_RoundEnd, null);
        CreateTimer(300.0, Timer_DelayRTV, _, TIMER_FLAG_NO_MAPCHANGE);
    }
}

void ResetRTV()
{
    for(int i = 1; i <= MaxClients+1; i++)
        g_bVoted[i] = false;
}

public Action Timer_ChangeMap(Handle timer)
{
    FindConVar("mp_halftime").SetInt(0);
    FindConVar("mp_timelimit").SetInt(0);
    FindConVar("mp_maxrounds").SetInt(0);
    FindConVar("mp_roundtime").SetInt(1);

    CS_TerminateRound(12.0, CSRoundEnd_Draw, true);

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

public Action Command_ForceRTV(int client, int args)
{
    StartRTV();
    PrintToChatAll("[\x04MCR\x01]  已强制启动RTV投票");
    return Plugin_Handled;
}

bool RTV_CheckStatus(int client, bool notice, bool self)
{
    int need, done;
    GetPlayers(need, done);

    if(notice)
    {
        if(self)
            PrintToChatAll("[\x04MCR\x01]  您已发起RTV投票. (\x07%d\x01/\x04%d\x01票)", done, need);
        else
            PrintToChatAll("[\x04MCR\x01]  \x05%N\x01想要RTV投票. (\x07%d\x01/\x04%d\x01票)", client, done, need);
    }

    return (done >= need);
}

void GetPlayers(int &need, int &done)
{
    need = 0;
    done = 0;

    for(int client = 1; client <= MaxClients; client++)
        if(IsClientInGame(client) && !IsFakeClient(client) && !IsClientSourceTV(client))
        {
            need++;
            if(g_bVoted[client])
                done++;
        }

    need = RoundFloat(need*0.6);    
}
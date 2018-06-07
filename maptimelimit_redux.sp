#pragma semicolon 1
#pragma newdecls required

#include <mapchooser_redux>

bool g_bAllowEXT;
bool g_bVoted[MAXPLAYERS+1];
ConVar mp_timelimit;

public Plugin myinfo =
{
    name        = "Map Time Extend Redux",
    author      = "Kyle",
    description = "Extend map timelimit",
    version     = MCR_VERSION,
    url         = "https://kxnrl.com"
};

public void OnPluginStart()
{
    mp_timelimit = FindConVar("mp_timelimit");

    CreateTimer(180.0, Timer_BroadCast, _, TIMER_REPEAT);
}

public Action Timer_BroadCast(Handle timer)
{
    PrintToChatAll("[\x04MCR\x01]  \x07!rtv\x01可以发起投票换图, \x07!ext\x01可以发起投票延长");
    return Plugin_Continue;
}

public void OnMapStart()
{
    g_bAllowEXT = false;
    CreateTimer(300.0, Timer_DelayEXT, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_DelayEXT(Handle timer)
{
    g_bAllowEXT = true;
    return Plugin_Stop;
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

    if(strcmp(sArgs, ".ext", false) != 0 && strcmp(sArgs, "!ext", false) != 0)
        return;

    AttemptEXT(client);
}

void AttemptEXT(int client)
{
    if(!g_bAllowEXT)
    {
        PrintToChat(client, "[\x04MCR\x01]  当前不允许延长地图!");
        return;
    }

    if(g_bVoted[client])
    {
        EXT_CheckStatus(client, true, true);
        return;
    }

    g_bVoted[client] = true;

    if(EXT_CheckStatus(client, true, false)) 
        ExtendMap();
}

void ExtendMap()
{
    ResetEXT();
    g_bAllowEXT = false;

    int val = mp_timelimit.IntValue;
    mp_timelimit.SetInt(val+20);

    PrintToChatAll("[\x04MCR\x01]  \x0C投票成功,已将当前地图延长20分钟");
}

void ResetEXT()
{
    for(int i = 1; i <= MaxClients+1; i++)
        g_bVoted[i] = false;
}

bool EXT_CheckStatus(int client, bool notice, bool self)
{
    int need, done;
    GetPlayers(need, done);

    if(notice)
    {
        if(self)
            PrintToChat(client, "[\x04MCR\x01]  您已发起延长地图投票. (\x07%d\x01/\x04%d\x01票)", done, need);
        else
            PrintToChatAll("[\x04MCR\x01]  \x05%N\x01想要延长地图投票. (\x07%d\x01/\x04%d\x01票)", client, done, need);
    }

    return (done >= need);
}

void GetPlayers(int &need, int &done)
{
    need = 0;
    done = 0;
    
    int players = 0;

    for(int client = 1; client <= MaxClients; client++)
        if(IsClientInGame(client) && !IsFakeClient(client) && !IsClientSourceTV(client))
        {
            players++;
            if(g_bVoted[client])
                done++;
        }

    need = RoundToCeil(players*0.6); 

    if(need == 1 && players >= 2)
        need = 2;
}
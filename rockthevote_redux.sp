#pragma semicolon 1
#pragma newdecls required

#include <mapchooser_redux>
#include <nextmap>
#include <smutils>

bool g_bAllowRTV;
bool g_bInChange;
bool g_bVoted[MAXPLAYERS+1];

public Plugin myinfo =
{
    name        = "Rock The Vote Redux",
    author      = "Kyle",
    description = "Provides RTV Map Voting",
    version     = MCR_VERSION,
    url         = "https://www.kxnrl.com"
};

public void OnPluginStart()
{
    SMUtils_SetChatPrefix("[\x02M\x04C\x0CR\x01]");
    SMUtils_SetChatSpaces("   ");
    SMUtils_SetChatConSnd(false);
    SMUtils_SetTextDest(HUD_PRINTCENTER);
    
    LoadTranslations("com.kxnrl.mcr.translations");

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

    if(strcmp(sArgs, "rtv", false) == 0 || strcmp(sArgs[1], "rtv", false) == 0)
        AttemptRTV(client);
}

void AttemptRTV(int client)
{
    if(!g_bAllowRTV)
    {
        Chat(client, "%T", "rtv not allowed", client);
        return;
    }

    if(!CanMapChooserStartVote())
    {
        Chat(client, "%T", "rtv started", client);
        return;
    }
    
    if(HasEndOfMapVoteFinished())
    {
        char map[128];
        if(GetNextMap(map, 128))
        {
            Chat(client, "%T", "nominate vote complete", client, map);
            if(FindConVar("mcr_include_desctag").BoolValue)
            {
                char desc[128];
                GetMapDesc(map, desc, 128, false, false);
                Chat(client, "\x0A -> \x0E[\x05%s\x0E]", desc);
            }
        }
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
            
            tChatAll("%t", "rtv change map", map);
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

    for(int client = 1; client <= MaxClients; ++client)
    if(IsClientInGame(client))
    if(IsPlayerAlive(client))
    ForcePlayerSuicide(client);

    return Plugin_Stop;
}

public Action Command_ForceRTV(int client, int args)
{
    StartRTV();
    tChatAll("%t", "force rtv");
    return Plugin_Handled;
}

bool RTV_CheckStatus(int client, bool notice, bool self)
{
    int need, done;
    _CheckPlayer(need, done);

    if(notice)
    {
        if(self)
            Chat(client, "%T", "rtv self", client, done, need);
        else
            tChatAll("%t", "rtv broadcast", client, done, need);
    }

    return (done >= need);
}

void _CheckPlayer(int &need, int &done)
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
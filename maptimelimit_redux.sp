#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <mapchooser_redux>
#include <smutils>

#undef REQUIRE_PLUGIN
#include <fys.pupd>

bool g_bAllowEXT;
bool g_bVoted[MAXPLAYERS+1];
ConVar mcr_extend_enabled;
ConVar mcr_command_broadcast;

public Plugin myinfo =
{
    name        = "Map Time Extend Redux",
    author      = "Kyle",
    description = "Extend map timelimit",
    version     = MCR_VERSION,
    url         = "https://www.kxnrl.com"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    MarkNativeAsOptional("Pupd_CheckPlugin");
    return APLRes_Success;
}

public void OnPluginStart()
{
    SMUtils_SetChatPrefix("[\x02M\x04C\x0CR\x01]");
    SMUtils_SetChatSpaces("   ");
    SMUtils_SetChatConSnd(false);
    SMUtils_SetTextDest(HUD_PRINTCENTER);

    RegAdminCmd("sm_extend", Command_Extend, ADMFLAG_CHANGEMAP);

    RegConsoleCmd("sm_ext", Command_Ext);

    mcr_extend_enabled = CreateConVar("mcr_extend_enabled", "1", "Enable !ext command.", _, true, 0.0, true, 1.0);

    LoadTranslations("com.kxnrl.mcr.translations");

    CreateTimer(180.0, Timer_BroadCast, _, TIMER_REPEAT);

    AutoExecConfig(true, "maptimelimit_redux", "sourcemod/mapchooser");
}

public void OnAllPluginsLoaded()
{
    mcr_command_broadcast = FindConVar("mcr_command_broadcast");
}

bool AllowExt()
{
    return g_bAllowEXT && mcr_extend_enabled.BoolValue;
}

public void Pupd_OnCheckAllPlugins()
{
    Pupd_CheckPlugin(false, "https://build.kxnrl.com/updater/MCR/");
}

public Action Timer_BroadCast(Handle timer)
{
    tChatAll("%t", "mtl notification");
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

public Action Command_Extend(int client, int args)
{
    ExtendMap(client);
    LogAction(client, -1, "%L -> extend.", client);
    return Plugin_Handled;
}

Action Command_Ext(int client, int args)
{
    if (client)
        AttemptEXT(client);

    return Plugin_Handled;
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
    if (!client)
        return;

    if (strcmp(sArgs, "ext", false) == 0)
        AttemptEXT(client);
}

void AttemptEXT(int client)
{
    if (!AllowExt())
    {
        Chat(client, "%T", "mtl not allowed", client);
        return;
    }

    if (g_bVoted[client])
    {
        EXT_CheckStatus(client, true, false);
        return;
    }

    g_bVoted[client] = true;

    if (EXT_CheckStatus(client, true, mcr_command_broadcast.BoolValue)) 
        ExtendMap();
}

void ExtendMap(int admin = -1)
{
    ResetEXT();

    if (admin < 0)
    g_bAllowEXT = false;

    ExtendMapTimeLimit(1200); 

    if (admin < 0)
    tChatAll("%t", "mtl extend");
    else
    tChatAll("%t", "mtl extend admin", admin);
}

void ResetEXT()
{
    for(int i = 1; i <= MaxClients+1; i++)
        g_bVoted[i] = false;
}

bool EXT_CheckStatus(int client, bool notice, bool broadcast)
{
    int need, done;
    _CheckPlayer(need, done);

    if (notice)
    {
        if (!broadcast)
            Chat(client, "%T", "mtl self", client, done, need);
        else
            tChatAll("%t", "mtl broadcast", client, done, need);
    }

    return (done >= need);
}

void _CheckPlayer(int &need, int &done)
{
    need = 0;
    done = 0;
    
    int players = 0;

    for(int client = 1; client <= MaxClients; client++)
        if (IsClientInGame(client) && !IsFakeClient(client) && !IsClientSourceTV(client))
        {
            players++;
            if (g_bVoted[client])
                done++;
        }

    need = RoundToCeil(players*0.6); 

    if (need == 1 && players >= 2)
        need = 2;
}

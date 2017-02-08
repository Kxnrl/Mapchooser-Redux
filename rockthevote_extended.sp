#include <mapchooser>
#include <mapchooser_extended>
#include <nextmap>
#include <cstrike>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <kztimer>
#include <cg_core>

#pragma newdecls required

bool g_bCanRTV;
bool g_bAllowRTV;
bool g_bInChange;
bool g_bKzTimer;
bool g_bVoted[MAXPLAYERS+1];
int g_iVoters;
int g_iVotes;
int g_iVotesNeeded;

public Plugin myinfo =
{
	name		= "Rock The Vote Redux",
	author		= "Kyle",
	description = "Provides RTV Map Voting",
	version		= "1.0",
	url			= "http://steamcommunity.com/id/_xQy_/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	MarkNativeAsOptional("KZTimer_GetSkillGroup");
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
	g_iVoters = 0;
	g_iVotes = 0;
	g_iVotesNeeded = 0;
	g_bInChange = false;
	g_bKzTimer = false;
	
	for(int i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i))
			OnClientPostAdminCheck(i);	
}

public void OnMapEnd()
{
	g_bCanRTV = false;	
	g_bAllowRTV = false;
}

public void OnConfigsExecuted()
{	
	g_bCanRTV = true;
	g_bAllowRTV = false;
	CreateTimer(30.0, Timer_DelayRTV, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientPostAdminCheck(int client)
{
	if(IsFakeClient(client))
		return;
	
	g_bVoted[client] = false;

	g_iVoters++;
	g_iVotesNeeded = RoundToFloor(float(g_iVoters) * 0.6);
}

public void OnClientDisconnect(int client)
{
	if(IsFakeClient(client))
		return;

	if(g_bVoted[client])
		g_iVotes--;
	
	g_iVoters--;

	g_iVotesNeeded = RoundToFloor(float(g_iVoters) * 0.6);

	if(!g_bCanRTV)
		return;	

	if(g_iVotes && g_iVoters && g_iVotes >= g_iVotesNeeded && g_bAllowRTV) 
		StartRTV();
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
	if(!g_bCanRTV || !client || !IsAllowClient(client))
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
		PrintToChat(client, "[\x04MCE\x01]  %t", "Already Voted", g_iVotes, g_iVotesNeeded);
		return;
	}

	char name[64];
	GetClientName(client, name, 64);
	
	g_iVotes++;
	g_bVoted[client] = true;

	PrintToChatAll("[\x04MCE\x01]  %t", "RTV Requested", name, g_iVotes, g_iVotesNeeded);
	
	if(g_iVotes >= g_iVotesNeeded)
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
		if(FindPluginByFile("KZTimerGlobal.smx"))
			InitiateMapChooserVote(MapChange_Instant);
		else
			InitiateMapChooserVote(MapChange_RoundEnd);
		
		ResetRTV();

		g_bAllowRTV = false;
		CreateTimer(300.0, Timer_DelayRTV, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

void ResetRTV()
{
	g_iVotes = 0;

	for(int i=1; i<=MAXPLAYERS; i++)
		g_bVoted[i] = false;
}

public Action Timer_ChangeMap(Handle hTimer)
{
	SetConVarInt(FindConVar("mp_halftime"), 0);
	SetConVarInt(FindConVar("mp_timelimit"), 0);
	SetConVarInt(FindConVar("mp_maxrounds"), 0);
	SetConVarInt(FindConVar("mp_roundtime"), 1);
	
	CS_TerminateRound(12.0, CSRoundEnd_Draw, true);
	
	if(FindPluginByFile("KZTimerGlobal.smx"))
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
			return Plugin_Stop;	
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
	if(!g_bCanRTV || !client)
		return Plugin_Handled;

	PrintToChatAll("[\x04MCE\x01]  %t", "Initiated Vote Map");

	StartRTV();

	return Plugin_Handled;
}

bool IsAllowClient(int client)
{
	if(!g_bKzTimer)
		return true;
	
	if(KZTimer_GetSkillGroup(client) >= 2 || CG_IsClientVIP(client) || CG_GetClientGId(client) > 9900)
		return true;
	
	PrintToChat(client, "[\x04MCE\x01]  \x07你的KZ等级不够,禁止RTV");
	return false;
}
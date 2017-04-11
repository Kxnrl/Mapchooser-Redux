#pragma newdecls required

bool g_bVoted[MAXPLAYERS+1];
int g_iVoters;
int g_iVotes;
int g_iVotesNeeded;

public Plugin myinfo =
{
	name		= "Map Time Extend Redux",
	author		= "Kyle",
	description = "Extend map timelimit",
	version		= "1.0",
	url			= "http://steamcommunity.com/id/_xQy_/"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_ext", Command_Ext);
	CreateTimer(180.0, Timer_BroadCast, _, TIMER_REPEAT);
}

public Action Timer_BroadCast(Handle timer)
{
	PrintToChatAll("[\x04MCE\x01]  输入\x07!rtv\x01可以发起投票换图,输入\x07!ext\x01可以发起投票延长");
}

public void OnMapStart()
{
	g_iVoters = 0;
	g_iVotes = 0;
	g_iVotesNeeded = 0;

	for(int i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i))
			OnClientPostAdminCheck(i);	
}

public void OnClientPostAdminCheck(int client)
{
	if(IsFakeClient(client))
		return;
	
	g_bVoted[client] = false;
	g_iVoters++;
	g_iVotesNeeded = RoundToFloor(float(g_iVoters) * 0.7);
}

public void OnClientDisconnect(int client)
{
	if(IsFakeClient(client))
		return;

	if(g_bVoted[client])
		g_iVotes--;
	
	g_iVoters--;

	g_iVotesNeeded = RoundToFloor(float(g_iVoters) * 0.7);
}

public Action Command_Ext(int client, int args)
{
	AttemptEXT(client);
}

void AttemptEXT(int client)
{
	if(g_bVoted[client])
	{
		PrintToChat(client, "[\x04MCE\x01]  您已经发起了投票延长地图(现有%d票,仍需%d票)", g_iVotes, g_iVotesNeeded);
		return;
	}

	g_iVotes++;
	g_bVoted[client] = true;

	PrintToChatAll("[\x04MCE\x01]  %N 要滚动投票延长地图. (%d 票同意, 至少需要 %d 票)", client, g_iVotes, g_iVotesNeeded);
	
	if(g_iVotes >= g_iVotesNeeded)
		StartEXT();
}

void StartEXT()
{
	ResetEXT();
	SetConVarInt(FindConVar("mp_timelimit"), GetConVarInt(FindConVar("mp_timelimit"))+20);
	PrintToChatAll("[\x04MCE\x01]  \x0C投票成功,已将当前地图延长20分钟");
}

void ResetEXT()
{
	g_iVotes = 0;

	for(int client = 1; client <= MaxClients; ++client)
		g_bVoted[client] = false;
}
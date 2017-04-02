#include <mapchooser>
#include <mapchooser_extended>
#include <nextmap>
#include <store>
#include <cstrike>
#include <sdktools>

#pragma newdecls required

Handle g_NominationsResetForward;
Handle g_MapVoteStartedForward;
Handle g_MapVoteStartForward;
Handle g_MapVoteEndForward;

Handle g_tVote;
Handle g_tRetry;
Handle g_tWarning;

Handle g_hVoteMenu;
Handle g_hKvMapData;

ArrayList g_aMapList;
ArrayList g_aNominateList;
ArrayList g_aNominateOwners;
ArrayList g_aOldMapList;
ArrayList g_aNextMapList;

int g_iExtends;
int g_iMapFileSerial = -1;
int g_iNominateCount;
int g_iRunoffCount;
bool g_bHasVoteStarted;
bool g_bWaitingForVote;
bool g_bMapVoteCompleted;
bool g_bChangeMapInProgress;
bool g_bWarningInProgress;
bool g_bBlockedSlots;

MapChange g_eChangeTime;

enum TimerLocation
{
	TimerLocation_Hint = 0,
	TimerLocation_Center = 1,
	TimerLocation_Chat = 2
}

enum WarningType
{
	WarningType_Vote,
	WarningType_Revote
}

#define VOTE_EXTEND "##extend##"
#define VOTE_DONTCHANGE "##dontchange##"
#define LINE_ONE "##lineone##"
#define LINE_TWO "##linetwo##"
#define LINE_SPACER "##linespacer##"
#define FAILURE_TIMER_LENGTH 5

public Plugin myinfo =
{
	name		= "MapChooser Redux",
	author		= "Kyle",
	description = "Automated Map Voting with Extensions",
	version		= "1.0",
	url			= "http://steamcommunity.com/id/_xQy_/"
};

public void OnPluginStart()
{
	LoadTranslations("mapchooser_extended.phrases");
	LoadTranslations("basevotes.phrases");
	LoadTranslations("common.phrases");

	int iArraySize = ByteCountToCells(256);
	g_aMapList = CreateArray(iArraySize);
	g_aNominateList = CreateArray(iArraySize);
	g_aNominateOwners = CreateArray(1);
	g_aOldMapList = CreateArray(iArraySize);
	g_aNextMapList = CreateArray(iArraySize);

	RegAdminCmd("sm_mapvote", Command_Mapvote, ADMFLAG_CHANGEMAP, "sm_mapvote - Forces MapChooser to attempt to run a map vote now.");
	RegAdminCmd("sm_setnextmap", Command_SetNextmap, ADMFLAG_CHANGEMAP, "sm_setnextmap <map>");

	g_NominationsResetForward = CreateGlobalForward("OnNominationRemoved", ET_Ignore, Param_String, Param_Cell);
	g_MapVoteStartedForward = CreateGlobalForward("OnMapVoteStarted", ET_Ignore);
	g_MapVoteStartForward = CreateGlobalForward("OnMapVoteStart", ET_Ignore);
	g_MapVoteEndForward = CreateGlobalForward("OnMapVoteEnd", ET_Ignore, Param_String);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("mapchooser");	

	CreateNative("NominateMap", Native_NominateMap);
	CreateNative("RemoveNominationByMap", Native_RemoveNominationByMap);
	CreateNative("RemoveNominationByOwner", Native_RemoveNominationByOwner);
	CreateNative("InitiateMapChooserVote", Native_InitiateVote);
	CreateNative("CanMapChooserStartVote", Native_CanVoteStart);
	CreateNative("HasEndOfMapVoteFinished", Native_CheckVoteDone);
	CreateNative("GetExcludeMapList", Native_GetExcludeMapList);
	CreateNative("GetNominatedMapList", Native_GetNominatedMapList);
	CreateNative("EndOfMapVoteEnabled", Native_EndOfMapVoteEnabled);
	CreateNative("CanNominate", Native_CanNominate);
	
	return APLRes_Success;
}

public void OnConfigsExecuted()
{
	CheckMapCycle();
	BuildKvMapData();

	if(ReadMapList(g_aMapList, g_iMapFileSerial, "mapchooser", MAPLIST_FLAG_CLEARARRAY|MAPLIST_FLAG_MAPSFOLDER) != INVALID_HANDLE)
		if(g_iMapFileSerial == -1)
			SetFailState("Unable to create a valid map list.");

	SetConVarBool(FindConVar("mp_endmatch_votenextmap"), false);

	CreateNextVote();
	SetupTimeleftTimer();

	g_iExtends = 0;
	g_bMapVoteCompleted = false;
	g_iNominateCount = 0;

	ClearArray(g_aNominateList);
	ClearArray(g_aNominateOwners);

	if(GetArraySize(g_aOldMapList) < 1)
	{
		char filepath[128];
		Handle file;
		BuildPath(Path_SM, filepath, 128, "data/mapchooser_oldlist.txt");
	
		if(!FileExists(filepath))
		{
			file = OpenFile(filepath, "w");
			CloseHandle(file);
			return;
		}

		if((file = OpenFile(filepath, "r")) != INVALID_HANDLE)
		{
			ClearArray(g_aOldMapList);

			char fileline[128];

			while(ReadFileLine(file, fileline, 128))
			{
				TrimString(fileline);
				
				if(!StrContains(fileline, "de_", false) || !StrContains(fileline, "cs_", false) || !StrContains(fileline, "gd_", false) || !StrContains(fileline, "train", false) || !StrContains(fileline, "ar_", false))
					continue;
				
				PushArrayString(g_aOldMapList, fileline);
			}

			CloseHandle(file);
		}
	}
}

public void OnMapEnd()
{
	g_bHasVoteStarted = false;
	g_bWaitingForVote = false;
	g_bChangeMapInProgress = false;

	g_tVote = INVALID_HANDLE;
	g_tRetry = INVALID_HANDLE;
	g_tWarning = INVALID_HANDLE;
	g_iRunoffCount = 0;
	
	char map[128];
	GetCurrentMap(map, 128);
	PushArrayString(g_aOldMapList, map);

	if(GetArraySize(g_aOldMapList) > 30)
		RemoveFromArray(g_aOldMapList, 0);
	
	char filepath[128];
	BuildPath(Path_SM, filepath, 128, "data/mapchooser_oldlist.txt");

	if(FileExists(filepath))
		DeleteFile(filepath);

	Handle file = OpenFile(filepath, "w");

	if(file == INVALID_HANDLE)
	{
		LogError("Open old map list fialed");
		return;
	}

	int size = GetArraySize(g_aOldMapList);

	for(int i = 0; i < size; ++i)
	{
		GetArrayString(g_aOldMapList, i, map, 128);
		WriteFileLine(file, map);
	}

	CloseHandle(file);
}

public void OnClientDisconnect(int client)
{
	int index = FindValueInArray(g_aNominateOwners, client);

	if(index == -1)
		return;
	
	char oldmap[256];
	GetArrayString(g_aNominateList, index, oldmap, 256);
	Call_StartForward(g_NominationsResetForward);
	Call_PushString(oldmap);
	Call_PushCell(GetArrayCell(g_aNominateOwners, index));
	Call_Finish();

	RemoveFromArray(g_aNominateOwners, index);
	RemoveFromArray(g_aNominateList, index);
	g_iNominateCount--;
}

public Action Command_SetNextmap(int client, int args)
{
	if(args < 1)
	{
		ReplyToCommand(client, "[\x04MCE\x01]  Usage: sm_setnextmap <map>");
		return Plugin_Handled;
	}

	char map[256];
	GetCmdArg(1, map, 256);

	if(!IsMapValid(map))
	{
		ReplyToCommand(client, "[\x04MCE\x01]  %t", "Map was not found", map);
		return Plugin_Handled;
	}

	LogAction(client, -1, "\"%L\" changed nextmap to \"%s\"", client, map);

	SetNextMap(map);
	g_bMapVoteCompleted = true;

	return Plugin_Handled;
}

public void OnMapTimeLeftChanged()
{
	if(GetArraySize(g_aMapList))
		SetupTimeleftTimer();
}

void SetupTimeleftTimer()
{
	int timeLeft;
	if(GetMapTimeLeft(timeLeft) && timeLeft > 0)
	{
		if(timeLeft - 300 < 0 && !g_bMapVoteCompleted && !g_bHasVoteStarted)
			SetupWarningTimer(WarningType_Vote);
		else
		{
			if(g_tWarning == INVALID_HANDLE)
			{
				if(g_tVote != INVALID_HANDLE)
				{
					KillTimer(g_tVote);
					g_tVote = INVALID_HANDLE;
				}	

				int timeLimit;
				GetMapTimeLimit(timeLimit);
				g_tVote = CreateTimer(float(timeLimit*60 - 300), Timer_StartWarningTimer, _, TIMER_FLAG_NO_MAPCHANGE);
			}
		}		
	}
}

public Action Timer_StartWarningTimer(Handle timer)
{
	g_tVote = INVALID_HANDLE;
	
	if(!g_bWarningInProgress || g_tWarning == INVALID_HANDLE)
		SetupWarningTimer(WarningType_Vote);
}

public Action Timer_StartMapVote(Handle timer, Handle data)
{
	static int timePassed;

	if(!GetArraySize(g_aMapList) || g_bMapVoteCompleted || g_bHasVoteStarted)
	{
		g_tWarning = INVALID_HANDLE;
		return Plugin_Stop;
	}

	ResetPack(data);
	int warningMaxTime = ReadPackCell(data);
	int warningTimeRemaining = warningMaxTime - timePassed;

	char warningPhrase[32];
	ReadPackString(data, warningPhrase, 32);

	if(timePassed == 0)
	{
		TimerLocation timerLocation;
		if(FindPluginByFile("KZTimerGlobal.smx"))
			timerLocation = TimerLocation_Chat;
		else
			timerLocation = TimerLocation_Hint;
		
		switch(timerLocation)
		{
			case TimerLocation_Center: PrintCenterTextAll("%t", warningPhrase, warningTimeRemaining);
			case TimerLocation_Chat: PrintToChatAll("[\x04MCE\x01]  %t", warningPhrase, warningTimeRemaining);
			default: PrintHintTextToAll("%t", warningPhrase, warningTimeRemaining);
		}
	}

	if(timePassed++ >= warningMaxTime)
	{
		if(timer == g_tRetry)
		{
			g_bWaitingForVote = false;
			g_tRetry = INVALID_HANDLE;
		}
		else
		{
			g_tWarning = INVALID_HANDLE;
		}
	
		timePassed = 0;
		MapChange mapChange = view_as<MapChange>(ReadPackCell(data));
		Handle hndl = view_as<Handle>(ReadPackCell(data));
		
		InitiateVote(mapChange, hndl);
		
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public Action Command_Mapvote(int client, int args)
{
	PrintToChatAll("[\x04MCE\x01]  %t", "Initiated Vote Map");

	SetupWarningTimer(WarningType_Vote, MapChange_MapEnd, INVALID_HANDLE, true);

	return Plugin_Handled;	
}

void InitiateVote(MapChange when, Handle inputlist = INVALID_HANDLE)
{
	g_bWaitingForVote = true;
	g_bWarningInProgress = false;
 
	if(IsVoteInProgress())
	{
		PrintToChatAll("[\x04MCE\x01]  %t", "Cannot Start Vote", FAILURE_TIMER_LENGTH);
		Handle data;
		g_tRetry = CreateDataTimer(1.0, Timer_StartMapVote, data, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);

		WritePackCell(data, FAILURE_TIMER_LENGTH);

		if(g_iRunoffCount > 0)
			WritePackString(data, "Revote Warning");
		else
			WritePackString(data, "Vote Warning");

		WritePackCell(data, view_as<int>(when));
		WritePackCell(data, view_as<int>(inputlist));
		ResetPack(data);

		return;
	}
	
	if(g_bMapVoteCompleted && g_bChangeMapInProgress)
		return;


	g_eChangeTime = when;
	
	g_bWaitingForVote = false;
		
	g_bHasVoteStarted = true;


	Handle menuStyle = GetMenuStyleHandle(view_as<MenuStyle>(0));

	if(menuStyle != INVALID_HANDLE)
		g_hVoteMenu = CreateMenuEx(menuStyle, Handler_MapVoteMenu, MenuAction_End | MenuAction_Display | MenuAction_DisplayItem | MenuAction_VoteCancel);
	else
		g_hVoteMenu = CreateMenu(Handler_MapVoteMenu, MenuAction_End | MenuAction_Display | MenuAction_DisplayItem | MenuAction_VoteCancel);

	Handle radioStyle = GetMenuStyleHandle(MenuStyle_Radio);

	if(GetMenuStyle(g_hVoteMenu) == radioStyle)
	{
		g_bBlockedSlots = true;
		AddMenuItem(g_hVoteMenu, LINE_ONE, "Choose something...", ITEMDRAW_DISABLED);
		AddMenuItem(g_hVoteMenu, LINE_TWO, "...will ya?", ITEMDRAW_DISABLED);
	}
	else
		g_bBlockedSlots = false;
	
	SetMenuOptionFlags(g_hVoteMenu, MENUFLAG_BUTTON_NOVOTE);
	
	SetMenuTitle(g_hVoteMenu, "选择下一张地图\n ");
	SetVoteResultCallback(g_hVoteMenu, Handler_MapVoteFinished);

	char map[256];

	if(inputlist == INVALID_HANDLE)
	{
		int nominateCount = GetArraySize(g_aNominateList);
		int voteSize = 5;

		int nominationsToAdd = nominateCount >= voteSize ? voteSize : nominateCount;

		for(int i = 0; i < nominationsToAdd; i++)
		{
			GetArrayString(g_aNominateList, i, map, 256);

			AddMapItem(map);
			RemoveStringFromArray(g_aNextMapList, map);

			Call_StartForward(g_NominationsResetForward);
			Call_PushString(map);
			Call_PushCell(GetArrayCell(g_aNominateOwners, i));
			Call_Finish();
		}

		for(int i = nominationsToAdd; i < nominateCount; i++)
		{
			GetArrayString(g_aNominateList, i, map, 256);

			Call_StartForward(g_NominationsResetForward);
			Call_PushString(map);
			Call_PushCell(GetArrayCell(g_aNominateOwners, i));
			Call_Finish();
		}

		int i = nominationsToAdd;
		int count = 0;
		int availableMaps = GetArraySize(g_aNextMapList);
		
		if(i < voteSize && availableMaps == 0)
		{
			if(i == 0)
			{
				LogError("No maps available for vote.");
				return;
			}
			else
			{
				LogMessage("Not enough maps to fill map list.");
				voteSize = i;
			}
		}

		while(i < voteSize)
		{
			GetArrayString(g_aNextMapList, count, map, 256);		
			count++;

			AddMapItem(map);
			i++;

			if(count >= availableMaps)
				break;
		}
		
		g_iNominateCount = 0;
		ClearArray(g_aNominateOwners);
		ClearArray(g_aNominateList);
		
		AddExtendToMenu(g_hVoteMenu, when);
	}
	else
	{
		int size = GetArraySize(inputlist);
		
		for(int i=0; i<size; i++)
		{
			GetArrayString(inputlist, i, map, 256);
			
			if(IsMapValid(map))
				AddMapItem(map);
			else if(StrEqual(map, VOTE_DONTCHANGE))
				AddMenuItem(g_hVoteMenu, VOTE_DONTCHANGE, "Don't Change");
			else if(StrEqual(map, VOTE_EXTEND))
				AddMenuItem(g_hVoteMenu, VOTE_EXTEND, "Extend Map");
		}
		CloseHandle(inputlist);
	}

	if(5 <= GetMaxPageItems(GetMenuStyle(g_hVoteMenu)))
		SetMenuPagination(g_hVoteMenu, MENU_NO_PAGINATION);
	
	VoteMenuToAll(g_hVoteMenu, 15);

	Call_StartForward(g_MapVoteStartForward);
	Call_Finish();

	Call_StartForward(g_MapVoteStartedForward);
	Call_Finish();

	LogAction(-1, -1, "Voting for next map has started.");
	PrintToChatAll("[\x04MCE\x01]  %t", "Nextmap Voting Started");
}

public void Handler_VoteFinishedGeneric(Menu menu, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	char map[256];
	GetMapItem(menu, item_info[0][VOTEINFO_ITEM_INDEX], map, 256);

	Call_StartForward(g_MapVoteEndForward);
	Call_PushString(map);
	Call_Finish();

	if(!strcmp(map, VOTE_EXTEND, false))
	{
		g_iExtends++;
		
		int timeLimit;
		if(GetMapTimeLimit(timeLimit))
			if(timeLimit > 0)
				ExtendMapTimeLimit(1200);						

		PrintToChatAll("[\x04MCE\x01]  %t", "Current Map Extended", RoundToFloor(float(item_info[0][VOTEINFO_ITEM_VOTES])/float(num_votes)*100), num_votes);
		LogAction(-1, -1, "Voting for next map has finished. The current map has been extended.");

		g_bHasVoteStarted = false;
		CreateNextVote();
		SetupTimeleftTimer();
	}
	else if(!strcmp(map, VOTE_DONTCHANGE, false))
	{
		PrintToChatAll("[\x04MCE\x01]  %t", "Current Map Stays", RoundToFloor(float(item_info[0][VOTEINFO_ITEM_VOTES])/float(num_votes)*100), num_votes);
		LogAction(-1, -1, "Voting for next map has finished. 'No Change' was the winner");
		
		g_bHasVoteStarted = false;
		CreateNextVote();
		SetupTimeleftTimer();
	}
	else
	{
		if(g_eChangeTime == MapChange_MapEnd)
			SetNextMap(map);
		else if(g_eChangeTime == MapChange_Instant)
		{
			CreateTimer(10.0 , Timer_ChangeMaprtv);
			SetNextMap(map);
			SetConVarString(FindConVar("nextlevel"), map);
			g_bChangeMapInProgress = false;
		}
		else
		{
			SetNextMap(map);
			SetConVarString(FindConVar("nextlevel"), map);

			SetConVarInt(FindConVar("mp_timelimit"), 1);
		}
		
		g_bHasVoteStarted = false;
		g_bMapVoteCompleted = true;
		
		PrintToChatAll("[\x04MCE\x01]  %t", "Nextmap Voting Finished", map, RoundToFloor(float(item_info[0][VOTEINFO_ITEM_VOTES])/float(num_votes)*100), num_votes);
		LogAction(-1, -1, "Voting for next map has finished. Nextmap: %s.", map);
	}	
}

public Action Timer_ChangeMaprtv(Handle hTimer)
{
	g_bChangeMapInProgress = false;

	SetConVarInt(FindConVar("mp_halftime"), 0);
	SetConVarInt(FindConVar("mp_timelimit"), 0);
	SetConVarInt(FindConVar("mp_maxrounds"), 0);
	SetConVarInt(FindConVar("mp_roundtime"), 1);
	
	CS_TerminateRound(12.0, CSRoundEnd_Draw, true);
	
	if(FindPluginByFile("KZTimerGlobal.smx"))
	{
		CreateTimer(10.0, Timer_ChangeMap, INVALID_HANDLE, TIMER_FLAG_NO_MAPCHANGE);
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

public void Handler_MapVoteFinished(Menu menu, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	if(num_items > 1 && g_iRunoffCount < 1)
	{
		g_iRunoffCount++;
		int highest_votes = item_info[0][VOTEINFO_ITEM_VOTES];
		int required_percent = 50;
		int required_votes = RoundToCeil(float(num_votes) * float(required_percent) / 100);
		
		if(highest_votes == item_info[1][VOTEINFO_ITEM_VOTES])
		{
			g_bHasVoteStarted = false;
			
			int iArraySize = ByteCountToCells(256);
			Handle mapList = CreateArray(iArraySize);

			for(int i = 0; i < num_items; i++)
			{
				if(item_info[i][VOTEINFO_ITEM_VOTES] == highest_votes)
				{
					char map[256];
					GetMapItem(menu, item_info[i][VOTEINFO_ITEM_INDEX], map, 256);
					PushArrayString(mapList, map);
				}
				else
					break;
			}
			
			PrintToChatAll("[\x04MCE\x01]  %t", "Tie Vote", GetArraySize(mapList));
			SetupWarningTimer(WarningType_Revote, view_as<MapChange>(g_eChangeTime), mapList);
			return;
		}
		else if(highest_votes < required_votes)
		{
			g_bHasVoteStarted = false;
			
			int iArraySize = ByteCountToCells(256);
			Handle mapList = CreateArray(iArraySize);

			char map1[256];
			GetMapItem(menu, item_info[0][VOTEINFO_ITEM_INDEX], map1, 256);

			PushArrayString(mapList, map1);

			for(int i = 1; i < num_items; i++)
			{
				if(GetArraySize(mapList) < 2 || item_info[i][VOTEINFO_ITEM_VOTES] == item_info[i - 1][VOTEINFO_ITEM_VOTES])
				{
					char map[256];
					GetMapItem(menu, item_info[i][VOTEINFO_ITEM_INDEX], map, 256);
					PushArrayString(mapList, map);
				}
				else
					break;
			}
			PrintToChatAll("[\x04MCE\x01]  %t", "Revote Is Needed", required_percent);
			SetupWarningTimer(WarningType_Revote, view_as<MapChange>(g_eChangeTime), mapList);
			return;
		}
	}

	Handler_VoteFinishedGeneric(menu, num_votes, num_clients, client_info, num_items, item_info);
}

public int Handler_MapVoteMenu(Handle menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_End:
		{
			g_hVoteMenu = INVALID_HANDLE;
			CloseHandle(menu);
		}
		case MenuAction_Display:
		{
			char buffer[256];
			Format(buffer, 256, "%T\n ", "Vote Nextmap", param1);
			Handle panel = view_as<Handle>(param2);
			SetPanelTitle(panel, buffer);
		}
		case MenuAction_DisplayItem:
		{
			char map[256];
			char buffer[256];
			
			GetMenuItem(menu, param2, map, 256);
			
			if(StrEqual(map, VOTE_EXTEND, false))
				Format(buffer, 256, "%T", "Extend Map", param1);
			else if(StrEqual(map, VOTE_DONTCHANGE, false))
				Format(buffer, 256, "%T", "Dont Change", param1);
			else if(StrEqual(map, LINE_ONE, false))
				Format(buffer, 256,"%T", "Line One", param1);
			else if(StrEqual(map, LINE_TWO, false))
				Format(buffer, 256,"%T", "Line Two", param1);
			
			if(buffer[0] != '\0')
				return RedrawMenuItem(buffer);
		}
		case MenuAction_VoteCancel:
		{
			if(param1 == VoteCancel_NoVotes)
			{
				int count = GetMenuItemCount(menu);
				
				int item;
				char map[256];
				
				do
				{
					int startInt = 0;
					if(g_bBlockedSlots)
						startInt = 2;
					item = GetRandomInt(startInt, count - 1);
					GetMenuItem(menu, item, map, 256);
				}
				while(!strcmp(map, VOTE_EXTEND, false));
				
				SetNextMap(map);
				g_bMapVoteCompleted = true;
			}
			g_bHasVoteStarted = false;
		}
	}

	return 0;
}

public Action Timer_ChangeMap(Handle hTimer, Handle dp)
{
	g_bChangeMapInProgress = false;

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

bool RemoveStringFromArray(Handle array, char[] str)
{
	int index = FindStringInArray(array, str);
	if(index != -1)
	{
		RemoveFromArray(array, index);
		return true;
	}

	return false;
}

void CreateNextVote()
{
	assert(g_aNextMapList)
	ClearArray(g_aNextMapList);

	char map[256];
	Handle tempMaps  = CloneArray(g_aMapList);
	
	GetCurrentMap(map, 256);
	RemoveStringFromArray(tempMaps, map);
	
	if(GetArraySize(tempMaps) > 20)
	{
		for(int i = 0; i < GetArraySize(g_aOldMapList); i++)
		{
			GetArrayString(g_aOldMapList, i, map, 256);
			RemoveStringFromArray(tempMaps, map);
		}	
	}

	int limit = (5 < GetArraySize(tempMaps) ? 5 : GetArraySize(tempMaps));

	for(int i = 0; i < limit; i++)
	{
		int b = GetRandomInt(0, GetArraySize(tempMaps) - 1);
		GetArrayString(tempMaps, b, map, 256);
		if(IsNiceMap(map) || IsBigMap(map))
			continue;
		PushArrayString(g_aNextMapList, map);
		RemoveFromArray(tempMaps, b);
	}
	
	CloseHandle(tempMaps);
}

bool CanVoteStart()
{
	if(g_bWaitingForVote || g_bHasVoteStarted)
		return false;

	return true;
}

NominateResult InternalNominateMap(char[] map, bool force, int owner)
{
	if(!IsMapValid(map))
		return Nominate_InvalidMap;
	
	if(FindStringInArray(g_aNominateList, map) != -1)
		return Nominate_AlreadyInVote;
	
	int index;

	if(owner && ((index = FindValueInArray(g_aNominateOwners, owner)) != -1))
	{
		char oldmap[256];
		GetArrayString(g_aNominateList, index, oldmap, 256);

		int credits = GetMapPrice(oldmap);
		Store_SetClientCredits(owner, Store_GetClientCredits(owner)+credits, "nomination-退还");
		PrintToChat(owner, "[\x04MCE\x01]  \x04你预定的[\x0C%s\x04]已被取消,已退还%d信用点", oldmap, credits);

		credits = GetMapPrice(map);
		if(Store_GetClientCredits(owner) < credits)
		{
			PrintToChat(owner, "[\x04MCE\x01]  \x04你的信用点余额不足,预定[\x0C%s\x04]失败", map);
			InternalRemoveNominationByOwner(owner);
			return Nominate_InvalidMap;
		}
		Store_SetClientCredits(owner, Store_GetClientCredits(owner)-credits, "nomination-预定");
		PrintToChat(owner, "[\x04MCE\x01]  \x04你预定[\x0C%s\x04]花费了%d信用点", map, credits);

		Call_StartForward(g_NominationsResetForward);
		Call_PushString(oldmap);
		Call_PushCell(owner);
		Call_Finish();

		SetArrayString(g_aNominateList, index, map);
		return Nominate_Replaced;
	}

	if(g_iNominateCount >= 5 && !force)
		return Nominate_VoteFull;

	int credits = GetMapPrice(map);
	if(Store_GetClientCredits(owner) < credits)
	{
		PrintToChat(owner, "[\x04MCE\x01]  \x04你的信用点余额不足,预定[\x0C%s\x04]失败", map);
		return Nominate_VoteFull;
	}
	Store_SetClientCredits(owner, Store_GetClientCredits(owner)-credits, "nomination-预定");
	PrintToChat(owner, "[\x04MCE\x01]  \x04你预定[\x0C%s\x04]花费了%d信用点", map, credits);

	PushArrayString(g_aNominateList, map);
	PushArrayCell(g_aNominateOwners, owner);
	g_iNominateCount++;
	
	while(GetArraySize(g_aNominateList) > 5)
	{
		char oldmap[256];
		GetArrayString(g_aNominateList, 0, oldmap, 256);
		Call_StartForward(g_NominationsResetForward);
		Call_PushString(oldmap);
		Call_PushCell(GetArrayCell(g_aNominateOwners, 0));
		Call_Finish();
		
		RemoveFromArray(g_aNominateList, 0);
		RemoveFromArray(g_aNominateOwners, 0);
	}

	return Nominate_Added;
}

public int Native_NominateMap(Handle plugin, int numParams)
{
	int len;
	GetNativeStringLength(1, len);
	
	if(len <= 0)
	  return false;
	
	char[] map = new char[len+1];
	GetNativeString(1, map, len+1);
	
	return view_as<int>(InternalNominateMap(map, GetNativeCell(2), GetNativeCell(3)));
}

bool InternalRemoveNominationByMap(char[] map)
{	
	for(int i = 0; i < GetArraySize(g_aNominateList); i++)
	{
		char oldmap[256];
		GetArrayString(g_aNominateList, i, oldmap, 256);

		if(strcmp(map, oldmap, false) == 0)
		{
			Call_StartForward(g_NominationsResetForward);
			Call_PushString(oldmap);
			Call_PushCell(GetArrayCell(g_aNominateOwners, i));
			Call_Finish();

			RemoveFromArray(g_aNominateList, i);
			RemoveFromArray(g_aNominateOwners, i);
			g_iNominateCount--;

			return true;
		}
	}
	
	return false;
}

public int Native_RemoveNominationByMap(Handle plugin, int numParams)
{
	int len;
	GetNativeStringLength(1, len);
	
	if(len <= 0)
	  return false;
	
	char[] map = new char[len+1];
	GetNativeString(1, map, len+1);
	
	return view_as<int>(InternalRemoveNominationByMap(map));
}

bool InternalRemoveNominationByOwner(int owner)
{	
	int index;

	if(owner && ((index = FindValueInArray(g_aNominateOwners, owner)) != -1))
	{
		char oldmap[256];
		GetArrayString(g_aNominateList, index, oldmap, 256);

		Call_StartForward(g_NominationsResetForward);
		Call_PushString(oldmap);
		Call_PushCell(owner);
		Call_Finish();

		RemoveFromArray(g_aNominateList, index);
		RemoveFromArray(g_aNominateOwners, index);
		g_iNominateCount--;

		return true;
	}
	
	return false;
}

public int Native_RemoveNominationByOwner(Handle plugin, int numParams)
{	
	return view_as<int>(InternalRemoveNominationByOwner(GetNativeCell(1)));
}

public int Native_InitiateVote(Handle plugin, int numParams)
{
	MapChange when = view_as<MapChange>(GetNativeCell(1));
	Handle inputarray = view_as<Handle>(GetNativeCell(2));
	
	LogAction(-1, -1, "Starting map vote because outside request");

	SetupWarningTimer(WarningType_Vote, when, inputarray);
}

public int Native_CanVoteStart(Handle plugin, int numParams)
{
	return CanVoteStart();	
}

public int Native_CheckVoteDone(Handle plugin, int numParams)
{
	return g_bMapVoteCompleted;
}

public int Native_GetExcludeMapList(Handle plugin, int numParams)
{
	Handle array = view_as<Handle>(GetNativeCell(1));
	
	if(array == INVALID_HANDLE)
		return;
	
	int size = GetArraySize(g_aOldMapList);
	char map[256];
	
	for(int i=0; i<size; i++)
	{
		GetArrayString(g_aOldMapList, i, map, 256);
		PushArrayString(array, map);	
	}
}

public int Native_GetNominatedMapList(Handle plugin, int numParams)
{
	Handle maparray = view_as<Handle>(GetNativeCell(1));
	Handle ownerarray = view_as<Handle>(GetNativeCell(2));
	
	if(maparray == INVALID_HANDLE)
		return;

	char map[256];

	for(int i = 0; i < GetArraySize(g_aNominateList); i++)
	{
		GetArrayString(g_aNominateList, i, map, 256);
		PushArrayString(maparray, map);

		if(ownerarray != INVALID_HANDLE)
		{
			int index = GetArrayCell(g_aNominateOwners, i);
			PushArrayCell(ownerarray, index);
		}
	}
}

public int Native_EndOfMapVoteEnabled(Handle plugin, int numParams)
{
	return true;
}

stock int SetupWarningTimer(WarningType type, MapChange when = MapChange_MapEnd, Handle mapList = INVALID_HANDLE, bool force = false)
{
	if(!GetArraySize(g_aMapList) || g_bChangeMapInProgress || g_bHasVoteStarted || (!force && g_bMapVoteCompleted))
		return;
	
	if(g_bWarningInProgress && g_tWarning != INVALID_HANDLE)
		KillTimer(g_tWarning);
	
	g_bWarningInProgress = true;
	
	int cvarTime;
	char translationKey[64];
	
	switch (type)
	{
		case WarningType_Vote:
		{
			cvarTime = 15;
			strcopy(translationKey, 64, "Vote Warning");
		}
		
		case WarningType_Revote:
		{
			cvarTime = 5;
			strcopy(translationKey, 64, "Revote Warning");
		}
	}

	Handle data;
	g_tWarning = CreateDataTimer(1.0, Timer_StartMapVote, data, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
	WritePackCell(data, cvarTime);
	WritePackString(data, translationKey);
	WritePackCell(data, view_as<int>(when));
	WritePackCell(data, view_as<int>(mapList));
	ResetPack(data);
}

stock bool IsMapEndVoteAllowed()
{
	if(g_bMapVoteCompleted || g_bHasVoteStarted)
		return false;
	else
		return true;
}

public int Native_IsWarningTimer(Handle plugin, int numParams)
{
	return g_bWarningInProgress;
}

public int Native_CanNominate(Handle plugin, int numParams)
{
	if(g_bHasVoteStarted)
		return view_as<int>(CanNominate_No_VoteInProgress);
	
	if(g_bMapVoteCompleted)
		return view_as<int>(CanNominate_No_VoteComplete);
	
	if(g_iNominateCount >= 5)
		return view_as<int>(CanNominate_No_VoteFull);
	
	return view_as<int>(CanNominate_Yes);
}

stock void AddMapItem(const char[] map)
{
	char szTrans[256];
	if(GetMapDesc(map, szTrans, 256))
		AddMenuItem(g_hVoteMenu, map, szTrans);
	else
		AddMenuItem(g_hVoteMenu, map, map);
}

stock void GetMapItem(Handle menu, int position, char[] map, int mapLen)
{
	GetMenuItem(menu, position, map, mapLen);
}

stock void AddExtendToMenu(Handle menu, MapChange when)
{
	if((when == MapChange_Instant || when == MapChange_RoundEnd))
		AddMenuItem(menu, VOTE_DONTCHANGE, "Don't Change");
	else if(g_iExtends < 3)
		AddMenuItem(menu, VOTE_EXTEND, "Extend Map");
}

stock int GetMapPrice(const char[] map)
{
	if(!g_hKvMapData)
		return 100;
	
	KvRewind(g_hKvMapData);

	if(!KvJumpToKey(g_hKvMapData, map, false))
		return 100;

	int credits = KvGetNum(g_hKvMapData, "Price", 0);

	return (credits > 100) ? credits : 100;
}

stock bool GetMapDesc(const char[] map, char[] desc, int maxLen)
{
	if(!g_hKvMapData)
		return false;
	
	KvRewind(g_hKvMapData);

	if(!KvJumpToKey(g_hKvMapData, map, false))
		return false;

	KvGetString(g_hKvMapData, "Desc", desc, maxLen, map);

	Format(desc, maxLen, "%s\n%s", map, desc);

	return true;
}

stock bool IsNiceMap(const char[] map)
{
	if(!g_hKvMapData)
		return false;
	
	KvRewind(g_hKvMapData);

	if(!KvJumpToKey(g_hKvMapData, map, false))
		return false;
	
	bool result = KvGetNum(g_hKvMapData, "Nice", 0) == 1 ? true : false;

	return result;
}

stock bool IsBigMap(const char[] map)
{
	if(!g_hKvMapData)
		return false;

	KvRewind(g_hKvMapData);

	if(!KvJumpToKey(g_hKvMapData, map, false))
		return false;
	
	bool result = KvGetNum(g_hKvMapData, "Size", 0) > 149 ? true : false;

	return result;
}

void BuildKvMapData()
{
	char path[128];
	BuildPath(Path_SM, path, 128, "configs/mapdata.txt");
	
	if(g_hKvMapData != INVALID_HANDLE)
		CloseHandle(g_hKvMapData);
	
	g_hKvMapData = CreateKeyValues("MapData", "", "");
	
	if(!FileExists(path))
		KeyValuesToFile(g_hKvMapData, path);
	else
		FileToKeyValues(g_hKvMapData, path);

	KvRewind(g_hKvMapData);
	
	char map[128];
	GetCurrentMap(map, 128);
	if(!KvJumpToKey(g_hKvMapData, map))
	{
		KvJumpToKey(g_hKvMapData, map, true);
		Format(map, 128, "maps/%s.bsp", map);
		KvSetString(g_hKvMapData, "Desc", "不详: 尚未明朗");
		KvSetNum(g_hKvMapData, "Price", 100);
		KvSetNum(g_hKvMapData, "Size", FileSize(map)/1048576+1);
		KvSetNum(g_hKvMapData, "Nice", 0);
		KvRewind(g_hKvMapData);
		KeyValuesToFile(g_hKvMapData, path);
	}
	
	KvRewind(g_hKvMapData);
}

void CheckMapCycle()
{
	char path[128];
	Format(path, 128, "mapcycle.txt");
	
	int counts, number;

	Handle hFile;
	if((hFile = OpenFile(path, "r")) != INVALID_HANDLE)
	{
		char fileline[128];
		while(ReadFileLine(hFile, fileline, 128))
        {
			if(fileline[0] == '\0')
				continue;

			counts++;
        }
		CloseHandle(hFile);
	}
	
	Handle hDirectory;
	if((hDirectory = OpenDirectory("maps")) != INVALID_HANDLE)
	{
		FileType type = FileType_Unknown;
		char filename[128];
		while(ReadDirEntry(hDirectory, filename, 128, type))
		{
			if(type != FileType_File)
				continue;
			
			TrimString(filename);

			if(StrContains(filename, ".bsp", false) == -1)
				continue;
			
			if(!StrContains(filename, "de_", false) || !StrContains(filename, "cs_", false) || !StrContains(filename, "gd_", false) || !StrContains(filename, "train", false) || !StrContains(filename, "ar_", false))
			{
				char path2[128];
				Format(path2, 128, "maps/%s", filename);
				if(DeleteFile(path2))
					LogMessage("Delete Offical map: %s", path2);
				
				continue;
			}

			number++;
		}
		CloseHandle(hDirectory);
	}
	
	if(counts == number)
		return;
	
	LogMessage("Build New MapCycle[old: %d current: %d]", counts, number);

	if((hFile = OpenFile(path, "w+")) != INVALID_HANDLE)
	{
		if((hDirectory = OpenDirectory("maps")) != INVALID_HANDLE)
		{
			FileType type = FileType_Unknown;
			char filename[128];
			while(ReadDirEntry(hDirectory, filename, 128, type))
			{
				if(type == FileType_File)
				{
					if(StrContains(filename, ".bsp", false) != -1)
					{
						ReplaceString(filename, 128, ".bsp", "", false);
						WriteFileLine(hFile, filename);
					}
				}
			}
			CloseHandle(hDirectory);
		}
		CloseHandle(hFile);
	}
}
#include <mapchooser>
#include <mapchooser_extended>

#pragma newdecls required

ArrayList g_aMapList;
Handle g_hMapMenu;
Handle g_hKvMapData = INVALID_HANDLE;
int g_iMapFileSerial = -1;

#define MAPSTATUS_ENABLED (1<<0)
#define MAPSTATUS_DISABLED (1<<1)
#define MAPSTATUS_EXCLUDE_CURRENT (1<<2)
#define MAPSTATUS_EXCLUDE_PREVIOUS (1<<3)
#define MAPSTATUS_EXCLUDE_NOMINATED (1<<4)

Handle g_aMapTrie;

public Plugin myinfo =
{
	name		= "Nominations Redux",
	author		= "Kyle",
	description = "Provides Map Nominations",
	version		= "1.0",
	url			= "http://steamcommunity.com/id/_xQy_/"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("nominations.phrases");
	LoadTranslations("basetriggers.phrases"); // for Next Map phrase
	LoadTranslations("mapchooser_extended.phrases");

	int arraySize = ByteCountToCells(256);	
	g_aMapList = CreateArray(arraySize);

	g_aMapTrie = CreateTrie();
}

public void OnConfigsExecuted()
{
	if(ReadMapList(g_aMapList, g_iMapFileSerial, "nominations", MAPLIST_FLAG_CLEARARRAY|MAPLIST_FLAG_MAPSFOLDER) == INVALID_HANDLE)
		if(g_iMapFileSerial == -1)
			SetFailState("Unable to create a valid map list.");

	BuildMapMenu();
	BuildKvMapData();
}

public void OnNominationRemoved(const char[] map, int owner)
{
	int status;
	
	if(!GetTrieValue(g_aMapTrie, map, status))
		return;	
	
	if((status & MAPSTATUS_EXCLUDE_NOMINATED) != MAPSTATUS_EXCLUDE_NOMINATED)
		return;

	SetTrieValue(g_aMapTrie, map, MAPSTATUS_ENABLED);	
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
	if(!client)
		return;

	if(StrContains(sArgs, "nominat", false) == -1)
		return;

	if(!IsNominateAllowed(client))
		return;

	AttemptNominate(client);
}

void AttemptNominate(int client)
{
	SetMenuTitle(g_hMapMenu, "%T\n ", "Nominate Title", client);
	DisplayMenu(g_hMapMenu, client, MENU_TIME_FOREVER);

	return;
}

void BuildMapMenu()
{
	if(g_hMapMenu != INVALID_HANDLE)
	{
		CloseHandle(g_hMapMenu);
		g_hMapMenu = INVALID_HANDLE;
	}

	ClearTrie(g_aMapTrie);

	g_hMapMenu = CreateMenu(Handler_MapSelectMenu, MENU_ACTIONS_DEFAULT|MenuAction_DrawItem|MenuAction_DisplayItem);

	char map[128];
	
	ArrayList excludeMaps = CreateArray(ByteCountToCells(128));
	GetExcludeMapList(excludeMaps);

	char currentMap[32];
	GetCurrentMap(currentMap, 32);
	
	for(int i = 0; i < GetArraySize(g_aMapList); i++)
	{
		int status = MAPSTATUS_ENABLED;

		GetArrayString(g_aMapList, i, map, 128);

		if(StrEqual(map, currentMap))
			status = MAPSTATUS_DISABLED|MAPSTATUS_EXCLUDE_CURRENT;

		if(status == MAPSTATUS_ENABLED)
			if(FindStringInArray(excludeMaps, map) != -1)
			status = MAPSTATUS_DISABLED|MAPSTATUS_EXCLUDE_PREVIOUS;

		char szTrans[256];
		if(GetMapDesc(map, szTrans, 256, true))
			AddMenuItem(g_hMapMenu, map, szTrans);
		else
			AddMenuItem(g_hMapMenu, map, map);

		SetTrieValue(g_aMapTrie, map, status);
	}

	SetMenuExitButton(g_hMapMenu, true);

	if(excludeMaps != INVALID_HANDLE)
		CloseHandle(excludeMaps);
}

public int Handler_MapSelectMenu(Handle menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char map[128], name[64];
			GetMenuItem(menu, param2, map, 128);		
			
			GetClientName(param1, name, 64);

			NominateResult result = NominateMap(map, false, param1);
			
			if(result == Nominate_AlreadyInVote)
			{
				PrintToChat(param1, "[\x04MCE\x01]  %t", "Map Already Nominated");
				return 0;
			}
			else if(result == Nominate_VoteFull)
			{
				PrintToChat(param1, "[\x04MCE\x01]  %t", "Max Nominations");
				return 0;
			}

			SetTrieValue(g_aMapTrie, map, MAPSTATUS_DISABLED|MAPSTATUS_EXCLUDE_NOMINATED);

			if(result == Nominate_Replaced)
			{
				PrintToChatAll("[\x04MCE\x01]  %t", "Map Nomination Changed", name, map);
				return 0;	
			}

			PrintToChatAll("[\x04MCE\x01]  %t", "Map Nominated", name, map);
			LogMessage("%s nominated %s", name, map);
		}

		case MenuAction_DrawItem:
		{
			char map[128];
			GetMenuItem(menu, param2, map, 128);

			int status;

			if(!GetTrieValue(g_aMapTrie, map, status))
			{
				LogError("case MenuAction_DrawItem: Menu selection of item not in trie. Major logic problem somewhere.");
				return ITEMDRAW_DEFAULT;
			}

			if((status & MAPSTATUS_DISABLED) == MAPSTATUS_DISABLED)
				return ITEMDRAW_DISABLED;	
	
			return ITEMDRAW_DEFAULT;
		}
		
		case MenuAction_DisplayItem:
		{
			char map[128];
			GetMenuItem(menu, param2, map, 128);

			int status;
			
			if(!GetTrieValue(g_aMapTrie, map, status))
			{
				LogError("case MenuAction_DisplayItem: Menu selection of item not in trie. Major logic problem somewhere.");
				return 0;
			}
			
			char buffer[100];
			char display[150];
			char trans[128];
			strcopy(buffer, 100, map);
			GetMapDesc(map, trans, 128, false);

			if((status & MAPSTATUS_DISABLED) == MAPSTATUS_DISABLED)
			{
				if((status & MAPSTATUS_EXCLUDE_CURRENT) == MAPSTATUS_EXCLUDE_CURRENT)
				{
					Format(display, sizeof(display), "%s (%T)\n%s", buffer, "Current Map", param1, trans);
					return RedrawMenuItem(display);
				}
				
				if((status & MAPSTATUS_EXCLUDE_PREVIOUS) == MAPSTATUS_EXCLUDE_PREVIOUS)
				{
					Format(display, sizeof(display), "%s (%T)\n%s", buffer, "Recently Played", param1, trans);
					return RedrawMenuItem(display);
				}
				
				if((status & MAPSTATUS_EXCLUDE_NOMINATED) == MAPSTATUS_EXCLUDE_NOMINATED)
				{
					Format(display, sizeof(display), "%s (%T)\n%s", buffer, "Nominated", param1, trans);
					return RedrawMenuItem(display);
				}
			}
			
			return 0;
		}
	}

	return 0;
}

stock bool IsNominateAllowed(int client)
{
	CanNominateResult result = CanNominate();
	
	switch(result)
	{
		case CanNominate_No_VoteInProgress:
		{
			PrintToChat(client, "[\x04MCE\x01]  %t", "Nextmap Voting Started");
			return false;
		}
		
		case CanNominate_No_VoteComplete:
		{
			char map[128];
			GetNextMap(map, 128);
			PrintToChat(client, "[\x04MCE\x01]  %t", "Next Map", map);
			return false;
		}
		
		case CanNominate_No_VoteFull:
		{
			PrintToChat(client, "[\x04MCE\x01]  %t", "Max Nominations");
			return false;
		}
	}
	
	return true;
}

void BuildKvMapData()
{
	char path[128];
	BuildPath(Path_SM, path, 128, "configs/mapdata.txt");
	
	if(!FileExists(path))
	{
		if(g_hKvMapData != INVALID_HANDLE)
			CloseHandle(g_hKvMapData);
		g_hKvMapData = INVALID_HANDLE;
		return;
	}
	
	g_hKvMapData = CreateKeyValues("MapData", "", "");
	FileToKeyValues(g_hKvMapData, path);
	KvRewind(g_hKvMapData);
}

stock bool GetMapDesc(const char[] map, char[] desc, int maxLen, bool includeName)
{
	if(!g_hKvMapData)
		return false;
	
	if(!KvJumpToKey(g_hKvMapData, map, false))
		return false;
	
	KvGetString(g_hKvMapData, "Desc", desc, maxLen, map);
	KvRewind(g_hKvMapData);
	
	if(includeName)
		Format(desc, maxLen, "%s\n%s", map, desc);

	return true;
}
#define MCE_VERSION "1.2.<commits>"

#define VOTE_EXTEND "##extend##"
#define VOTE_DONTCHANGE "##dontchange##"
#define LINE_ONE "##lineone##"
#define LINE_TWO "##linetwo##"
#define LINE_SPACER "##linespacer##"
#define FAILURE_TIMER_LENGTH 5

enum MapChange
{
	MapChange_Instant,		/** Change map as soon as the voting results have come in */
	MapChange_RoundEnd,		/** Change map at the end of the round */
	MapChange_MapEnd,		/** Change the sm_nextmap cvar */
};

enum CanNominateResult
{
    CanNominate_No_VoteFull,        /** No, nominations list is full */
    CanNominate_No_VoteInProgress,    /** No, map vote is in progress */
    CanNominate_No_VoteComplete,    /** No, map vote is completed */
    CanNominate_Yes,                /** Yes, you can nominate */
};

enum NominateResult
{
    NominateResult_Added,         /** The map was added to the nominate list */
    NominateResult_Replaced,      /** A clients existing nomination was replaced */
    NominateResult_AlreadyInVote, /** Specified map was already in the vote */
    NominateResult_InvalidMap,    /** Mapname specified wasn't a valid map */
    NominateResult_VoteFull,      /** This will only occur if force was set to false */
    NominateResult_MinPlayers,
    NominateResult_MaxPlayers,
    NominateResult_NoCredits,
    NominateResult_OnlyAdmin,
    NominateResult_OnlyVIP
};

KeyValues g_hKvMapData;

forward void OnNominationRemoved(const char[] map, int client);
forward void OnMapVoteStarted();
forward void OnMapVoteEnd(const char[] map);
forward void OnMapDataLoaded();

native CanNominateResult CanNominate();
native NominateResult NominateMap(const char[] map, bool force, int owner);
native bool RemoveNominationByMap(const char[] map);
native bool RemoveNominationByOwner(int client);
native void InitiateMapChooserVote(MapChange when, ArrayList inputarray);
native bool CanMapChooserStartVote();
native bool HasEndOfMapVoteFinished();
native void GetExcludeMapList(ArrayList array);
native void GetNominatedMapList(ArrayList maparray, ArrayList ownerarray);
native bool EndOfMapVoteEnabled();

// stocks
stock void AddMapItem(Handle menu, const char[] map, bool includeTag)
{
    char szTrans[256];
    if(GetMapDesc(map, szTrans, 256, true, includeTag))
        AddMenuItem(menu, map, szTrans);
    else
        AddMenuItem(menu, map, map);
}

stock int GetMapPrice(const char[] map)
{
    if(!g_hKvMapData)
        return 100;
    
    KvRewind(g_hKvMapData);

    if(!KvJumpToKey(g_hKvMapData, map, false))
        return 100;

    int credits = KvGetNum(g_hKvMapData, "Price", 0);

    return (credits < 100) ? 100 : credits;
}

stock bool GetMapDesc(const char[] map, char[] desc, int maxLen, bool includeName, bool includeTag)
{
    if(!g_hKvMapData)
        return false;
    
    KvRewind(g_hKvMapData);

    if(!KvJumpToKey(g_hKvMapData, map, false))
        return false;

    KvGetString(g_hKvMapData, "Desc", desc, maxLen, map);

    if(includeName)
        Format(desc, maxLen, "%s\n%s", map, desc);

    if(includeTag)
        Format(desc, maxLen, "[%s]%s", IsNiceMap(map) ? "神图" : "普通", desc);

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

stock int GetMinPlayers(const char[] map)
{
    if(!g_hKvMapData)
        return 0;
    
    KvRewind(g_hKvMapData);
    
    if(!KvJumpToKey(g_hKvMapData, map, false))
        return 0;
    
    return KvGetNum(g_hKvMapData, "MinPlayers", 0);
}

stock int GetMaxPlayers(const char[] map)
{
    if(!g_hKvMapData)
        return 0;
    
    KvRewind(g_hKvMapData);
    
    if(!KvJumpToKey(g_hKvMapData, map, false))
        return 0;
    
    return KvGetNum(g_hKvMapData, "MaxPlayers", 0);
}

stock bool IsOnlyNomination(const char[] map)
{
    if(!g_hKvMapData)
        return false;
    
    KvRewind(g_hKvMapData);

    if(!KvJumpToKey(g_hKvMapData, map, false))
        return false;
    
    bool result = KvGetNum(g_hKvMapData, "OnlyNomination", 0) == 1 ? true : false;

    return result;
}

stock bool IsOnlyAdmin(const char[] map)
{
    if(!g_hKvMapData)
        return false;
    
    KvRewind(g_hKvMapData);

    if(!KvJumpToKey(g_hKvMapData, map, false))
        return false;
    
    bool result = KvGetNum(g_hKvMapData, "OnlyAdmin", 0) == 1 ? true : false;

    return result;
}

stock bool IsOnlyVIP(const char[] map)
{
    if(!g_hKvMapData)
        return false;
    
    KvRewind(g_hKvMapData);

    if(!KvJumpToKey(g_hKvMapData, map, false))
        return false;
    
    bool result = KvGetNum(g_hKvMapData, "OnlyVIP", 0) == 1 ? true : false;

    return result;
}

stock int UTIL_GetRandomInt(int min, int max)
{
    int random = GetURandomInt();
    
    if(random == 0)
        random++;

    return RoundToCeil(float(random) / (float(2147483647) / float(max - min + 1))) + min - 1;
}
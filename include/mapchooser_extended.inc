#include <mapchooser>

// use on csgogamers server. if u are not run with core.smx plz comment this.
//#include <cg_core>


#define MCE_VERSION "1.2.39"

#define VOTE_EXTEND "##extend##"
#define VOTE_DONTCHANGE "##dontchange##"
#define LINE_ONE "##lineone##"
#define LINE_TWO "##linetwo##"
#define LINE_SPACER "##linespacer##"
#define FAILURE_TIMER_LENGTH 5

enum CanNominateResult
{
    CanNominate_No_VoteFull,        /** No, nominations list is full */
    CanNominate_No_VoteInProgress,    /** No, map vote is in progress */
    CanNominate_No_VoteComplete,    /** No, map vote is completed */
    CanNominate_Yes,                /** Yes, you can nominate */
};

enum NominateResult2
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

Handle g_hKvMapData;

/**
 * Called whenever warning timer starts
 * 
 */
forward void OnMapVoteWarningStart();

/**
 * Called whenever runoff warning timer starts
 */
forward void OnMapVoteRunnoffWarningStart();

/**
 * Called whenever the timer ticks
 */
forward void OnMapVoteWarningTick(int time);

/**
 * Called whenever vote starts
 * 
 * @deprecated Will be removed in MapChooser 1.8.  Use OnMapVoteStarted instead.
 */
forward void OnMapVoteStart();

/**
 * Called whenever vote ends
 */
forward void OnMapVoteEnd(const char[] map);

/**
 * Is a map on the current game's official list?
 * This should be treated as informative only.
 * 
 * @param map     Name of map to check
 * @return         true if it's on the list of official maps for this game
 */
native bool IsMapOfficial(const char[] map);

/**
 * Is nominate allowed?
 * 
 * @return        A CanNominateResult corresponding to whether a vote is allowed or not
 */
native CanNominateResult CanNominate();


forward void OnMapDataLoaded();
native NominateResult2 NominateMap2(const char[] map, bool force, int owner);


// stocks
stock void AddMapItem(Handle menu, const char[] map)
{
    char szTrans[256];
    if(GetMapDesc(map, szTrans, 256, true))
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

stock bool GetMapDesc(const char[] map, char[] desc, int maxLen, bool includeName)
{
    if(!g_hKvMapData)
        return false;
    
    KvRewind(g_hKvMapData);

    if(!KvJumpToKey(g_hKvMapData, map, false))
        return false;

    KvGetString(g_hKvMapData, "Desc", desc, maxLen, map);

    if(includeName)
        Format(desc, maxLen, "[%s]%s\n%s", IsNiceMap(map) ? "神图" : "普通", map, desc);

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
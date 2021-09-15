enum struct Forwards
{
    GlobalForward m_NominationsReset;
    GlobalForward m_MapVoteStarted;
    GlobalForward m_MapVoteEnd;
    GlobalForward m_MapDataLoaded;
    GlobalForward m_MapVotePoolChanged;
    GlobalForward m_NominationsVoted;
    GlobalForward m_OnNominatedMap;
    GlobalForward m_OnNominateMap;
    GlobalForward m_OnNominatePrice;
    GlobalForward m_OnClearMapCooldown;
    GlobalForward m_OnResetMapCooldown;
    GlobalForward m_OnNextMapListCreate;
}

static Forwards g_Forward;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    if (!CleanPlugin())
    {
        strcopy(error, err_max, "can not clean files.");
        return APLRes_Failure;
    }

    RegPluginLibrary("mapchooser");

    CreateNative("NominateMap",             Native_NominateMap);
    CreateNative("RemoveNominationByMap",   Native_RemoveNominationByMap);
    CreateNative("RemoveNominationByOwner", Native_RemoveNominationByOwner);
    CreateNative("InitiateMapChooserVote",  Native_InitiateVote);
    CreateNative("CanMapChooserStartVote",  Native_CanVoteStart);
    CreateNative("HasEndOfMapVoteFinished", Native_CheckVoteDone);
    CreateNative("GetExcludeMapList",       Native_GetExcludeMapList);
    CreateNative("GetNominatedMapList",     Native_GetNominatedMapList);
    CreateNative("EndOfMapVoteEnabled",     Native_EndOfMapVoteEnabled);
    CreateNative("CanNominate",             Native_CanNominate);
    CreateNative("GetMapData",              Native_GetMapData);
    CreateNative("GetPartyBlockOnwer",      Native_GetPartyBlockOnwer);
    CreateNative("ForceSetNextMap",         Native_ForceSetNextMap);
    CreateNative("SetTierString",           Native_OverrideTierString);
    CreateNative("GetTierString",           Native_GetTierString);

    MarkNativeAsOptional("Store_GetClientCredits");
    MarkNativeAsOptional("Store_SetClientCredits");

    MarkNativeAsOptional("MG_Shop_GetClientMoney");
    MarkNativeAsOptional("MG_Shop_ClientEarnMoney");
    MarkNativeAsOptional("MG_Shop_ClientCostMoney");

    MarkNativeAsOptional("Pupd_CheckPlugin");

    return APLRes_Success;
}

public void OnLibraryAdded(const char[] name)
{
    if (strcmp(name, "store") == 0)
        g_pStore = true;
    else if (strcmp(name, "shop-core") == 0)
        g_pShop = true;
}

public void OnLibraryRemoved(const char[] name)
{
    if (strcmp(name, "store") == 0)
        g_pStore = false;
    else if (strcmp(name, "shop-core") == 0)
        g_pShop = false;
}

void Natives_OnPluginStart()
{
    g_Forward.m_NominationsReset    = new GlobalForward("OnNominationRemoved",    ET_Ignore, Param_String, Param_Cell, Param_Cell);
    g_Forward.m_NominationsVoted    = new GlobalForward("OnNominationVoted",      ET_Ignore, Param_String, Param_String, Param_String);
    g_Forward.m_MapVoteStarted      = new GlobalForward("OnMapVoteStarted",       ET_Ignore);
    g_Forward.m_MapVoteEnd          = new GlobalForward("OnMapVoteEnd",           ET_Ignore, Param_String);
    g_Forward.m_MapDataLoaded       = new GlobalForward("OnMapDataLoaded",        ET_Ignore);
    g_Forward.m_MapVotePoolChanged  = new GlobalForward("OnMapVotePoolChanged",   ET_Ignore);
    g_Forward.m_OnNominateMap       = new GlobalForward("OnNominateMap",          ET_Hook,   Param_String, Param_Cell, Param_Cell);
    g_Forward.m_OnNominatedMap      = new GlobalForward("OnNominatedMap",         ET_Ignore, Param_String, Param_Cell, Param_Cell);
    g_Forward.m_OnNominatePrice     = new GlobalForward("OnNominatePrice",        ET_Hook,   Param_String, Param_Cell, Param_CellByRef, Param_Cell);
    g_Forward.m_OnClearMapCooldown  = new GlobalForward("OnClearMapCooldown",     ET_Hook,   Param_String, Param_Cell);
    g_Forward.m_OnResetMapCooldown  = new GlobalForward("OnResetMapCooldown",     ET_Hook,   Param_String, Param_Cell);
    g_Forward.m_OnNextMapListCreate = new GlobalForward("OnNextMapListCreate",    ET_Hook,   Param_String);
}

bool AllowInNextVotePool(const char[] map)
{
    bool allow = true;
    Call_StartForward(g_Forward.m_OnNextMapListCreate);
    Call_PushString(map);
    Call_Finish(allow);
    return allow;
}

bool Call_OnClearMapCooldown(const char[] map, int _cell)
{
    bool allow = true;
    Call_StartForward(g_Forward.m_OnClearMapCooldown);
    Call_PushString(map);
    Call_PushCell(_cell);
    Call_Finish(allow);
    return allow;
}

bool Call_OnResetMapCooldown(const char[] map, int _cell)
{
    bool allow = true;
    Call_StartForward(g_Forward.m_OnResetMapCooldown);
    Call_PushString(map);
    Call_PushCell(_cell);
    Call_Finish(allow);
    return allow;
}

bool Call_OnNominatePrice(const char[] map, int _cell, int &_ref, bool _bool)
{
    // module not found
    if (!g_pShop && !g_pStore)
        return true;

    bool allow = true;
    Call_StartForward(g_Forward.m_OnNominatePrice);
    Call_PushString(map);
    Call_PushCell(_cell);
    Call_PushCellRef(_ref);
    Call_PushCell(_bool);
    Call_Finish(allow);
    return allow;
}

bool Call_OnNominateMap(const char[] map, int _cell, bool _bool)
{
    bool allow = true;
    Call_StartForward(g_Forward.m_OnNominateMap);
    Call_PushString(map);
    Call_PushCell(_cell);
    Call_PushCell(_bool);
    Call_Finish(allow);
    return allow;
}

void Call_OnNominatedMap(const char[] map, int _cell, bool _bool)
{
    Call_StartForward(g_Forward.m_OnNominatedMap);
    Call_PushString(map);
    Call_PushCell(_cell);
    Call_PushCell(_bool);
    Call_Finish();
}

void Call_NominationsReset(const char[] map, int _cell, bool _bool)
{
    Call_StartForward(g_Forward.m_NominationsReset);
    Call_PushString(map);
    Call_PushCell(_cell);
    Call_PushCell(_bool);
    Call_Finish();
}

void Call_NominationsVoted(const char[] map, const char[] name, const char[] auth)
{
    Call_StartForward(g_Forward.m_NominationsVoted);
    Call_PushString(map);
    Call_PushString(name);
    Call_PushString(auth);
    Call_Finish();
}

void Call_MapVoteStarted()
{
    Call_StartForward(g_Forward.m_MapVoteStarted);
    Call_Finish();
}

void Call_MapVoteEnd(const char[] map)
{
    Call_StartForward(g_Forward.m_MapVoteEnd);
    Call_PushString(map);
    Call_Finish();
}

void Call_MapDataLoaded()
{
    Call_StartForward(g_Forward.m_MapDataLoaded);
    Call_Finish();
}

void Call_MapVotePoolChanged()
{
    Call_StartForward(g_Forward.m_MapVotePoolChanged);
    Call_Finish();
}

public any Native_RemoveNominationByMap(Handle plugin, int numParams)
{
    int len;
    GetNativeStringLength(1, len);

    if (len <= 0)
      return false;
    
    char[] map = new char[len+1];
    GetNativeString(1, map, len+1);

    return InternalRemoveNominationByMap(map);
}

public any Native_NominateMap(Handle plugin, int numParams)
{
    int len;
    GetNativeStringLength(1, len);

    if (len <= 0)
      return false;

    char[] map = new char[len+1];
    GetNativeString(1, map, len+1);

    return InternalNominateMap(map, GetNativeCell(2), GetNativeCell(3), GetNativeCell(4));
}

public any Native_IsWarningTimer(Handle plugin, int numParams)
{
    return g_bWarningInProgress;
}

public any Native_CanNominate(Handle plugin, int numParams)
{
    if (g_bHasVoteStarted)
        return CanNominate_No_VoteInProgress;
    
    if (g_bMapVoteCompleted)
        return CanNominate_No_VoteComplete;
    
    if (g_iNominateCount >= 5)
        return CanNominate_No_VoteFull;

    if (g_bPartyblock)
        return CanNominate_No_PartyBlock;

    return CanNominate_Yes;
}

public any Native_RemoveNominationByOwner(Handle plugin, int numParams)
{    
    return InternalRemoveNominationByOwner(GetNativeCell(1));
}

public any Native_InitiateVote(Handle plugin, int numParams)
{
    MapChange when = view_as<MapChange>(GetNativeCell(1));
    ArrayList maps = view_as<ArrayList>(GetNativeCell(2));

    LogAction(-1, -1, "Starting map vote because outside request");

    SetupWarningTimer(WarningType_Vote, when, maps);
}

public any Native_CanVoteStart(Handle plugin, int numParams)
{
    return CanVoteStart();    
}

public any Native_CheckVoteDone(Handle plugin, int numParams)
{
    return g_bMapVoteCompleted;
}

public any Native_GetExcludeMapList(Handle plugin, int numParams)
{
    GetCooldownMaps(view_as<ArrayList>(GetNativeCell(1)));
}

public any Native_GetNominatedMapList(Handle plugin, int numParams)
{
    ArrayList m_aNominations = view_as<ArrayList>(GetNativeCell(1));
    for (int i = 0; i < g_aNominations.Length; i++)
    {
        Nominations n;
        g_aNominations.GetArray(i, n, sizeof(Nominations));
        m_aNominations.PushArray(  n, sizeof(Nominations));
    }
}

public any Native_EndOfMapVoteEnabled(Handle plugin, int numParams)
{
    return true;
}

public any Native_GetPartyBlockOnwer(Handle plugin, int numParams)
{
    if (!g_bPartyblock || g_aNominations.Length == 0)
        return -1;

    Nominations n;
    g_aNominations.GetArray(0, n, sizeof(Nominations));

    return n.m_Owner;
}

public any Native_ForceSetNextMap(Handle plugin, int numParams)
{
    if (g_bMapVoteCompleted && !GetNativeCell(2))
        return false;

    char map[128];
    GetNativeString(1, map, 128);
    InternalSetNextMap(map);

    return true;
}

public any Native_OverrideTierString(Handle plugin, int numParams)
{
    int tier = GetNativeCell(1);
    if (tier < 0 || tier > MAX_TIER)
        return ThrowNativeError(SP_ERROR_PARAM, "Invalid tier <%d> gived.", tier);

    return GetNativeString(2, g_TierString[tier], 32) == SP_ERROR_NONE;
}

public any Native_GetTierString(Handle plugin, int numParams)
{
    int tier = GetNativeCell(1);
    if (tier < 0 || tier > MAX_TIER)
        return ThrowNativeError(SP_ERROR_PARAM, "Invalid tier <%d> gived.", tier);

    SetNativeString(2, g_TierString[tier], GetNativeCell(3));
    return true;
}
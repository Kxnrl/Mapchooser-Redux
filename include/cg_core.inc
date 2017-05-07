forward void CG_OnServerLoaded();
forward void CG_OnClientDailySign(int client);
forward void CG_OnClientLoaded(int client);
forward void CG_OnLilyCouple(int Neptune, int Noire);
forward void CG_OnLilyDivorce(int Neptune, int Noire);
forward void CG_OnNewDay(int date);
forward bool CG_OnCheckAuthTerm(int client, int authid);
forward bool CG_APIStoreSetCredits(int client, int credits, const char[] reason, bool immed);
forward  int CG_APIStoreGetCredits(int client);

forward void CG_OnRoundStart();
forward void CG_OnRoundEnd(int winner);
forward void CG_OnClientSpawn(int client);
forward void CG_OnClientDeath(int client, int attacker, int assister, bool headshot, const char[] weapon);
forward void CG_OnClientHurted(int client, int attacker, int damage, int hitgroup, const char[] weapon);
forward void CG_OnClientTeam(int client);
forward void CG_OnClientJump(int client);
forward void CG_OnClientFire(int client, const char[] weapon);

native    int CG_GetServerId();
native    int CG_GetClientOnlines(int client);
native    int CG_GetClientVitality(int client);
native    int CG_GetClientLastseen(int client);
native    int CG_GetClientId(int client);
native    int CG_GetClientUId(int client);
native    int CG_GetClientGId(int client);
native    int CG_GetClientVip(int client);
native    int CG_GetClientPartner(int client);
native    int CG_GetClientLilyDate(int client);
native    int HookClientVIPChecked(OnClientVIPChecked func);
native   bool CG_IsClientVIP(int client);
native   bool CG_ShowNormalMotd(int client, int width, int height, char[] url);
native   bool CG_ShowHiddenMotd(int client, char[] url);
native   bool CG_RemoveMotd(int client);
native   void CG_SetClientVIP(int client);
native   void CG_SaveDatabase(char[] QueryString);
native   void CG_SaveForumData(char[] QueryString);
native   void CG_GetClientSignature(int client, char[] buffer, int maxLen);
native   void CG_GetClientDName(int client, char[] buffer, int maxLen);
native   void CG_GetClientGName(int client, char[] buffer, int maxLen);
native Handle CG_GetGameDatabase();
native Handle CG_GetDiscuzDatabase();

typedef OnClientVIPChecked = function void (int client);
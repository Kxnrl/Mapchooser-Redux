#if defined _KZTimer_included
 #endinput
#endif
#define _KZTimer_included

native bool KZTimer_GetTimerStatus(int client);
native int KZTimer_StopTimer(int client);
native void KZTimer_StopUpdatingOfClimbersMenu(int client);
native void KZTimer_EmulateStartButtonPress(int client);
native void KZTimer_EmulateStopButtonPress(int client);
native float KZTimer_GetCurrentTime(int client);
native float KZTimer_GetAvgTimeTp();
native float KZTimer_GetAvgTimePro();
native int KZTimer_GetSkillGroup(int client);

public SharedPlugin __pl_KZTimerGlobal =
{
	name = "KZTimerGlobal",
	file = "KZTimerGlobal.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

public __pl_KZTimer_SetNTVOptional()
{
	MarkNativeAsOptional("KZTimer_GetTimerStatus");
	MarkNativeAsOptional("KZTimer_StopTimer");
	MarkNativeAsOptional("KZTimer_StopUpdatingOfClimbersMenu");
	MarkNativeAsOptional("KZTimer_EmulateStartButtonPress");	
	MarkNativeAsOptional("KZTimer_EmulateStopButtonPress");
	MarkNativeAsOptional("KZTimer_GetCurrentTime");
	MarkNativeAsOptional("KZTimer_GetAvgTimeTp");
	MarkNativeAsOptional("KZTimer_GetAvgTimePro");
	MarkNativeAsOptional("KZTimer_GetSkillGroup");
}
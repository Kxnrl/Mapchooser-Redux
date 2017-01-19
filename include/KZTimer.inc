#if defined _KZTimer_included
 #endinput
#endif
#define _KZTimer_included

/* Natives */
native bool:KZTimer_GetTimerStatus(client); // returns (bool) timer status
native KZTimer_StopTimer(client); // stops the timer
native KZTimer_StopUpdatingOfClimbersMenu(client); // stops refreshing of the timer panel/menu
native KZTimer_EmulateStartButtonPress(client); // start button alternative
native KZTimer_EmulateStopButtonPress(client); // stop button alternative
native Float:KZTimer_GetCurrentTime(client); //returns (float) current run time
native Float:KZTimer_GetAvgTimeTp(); //avg tp time - returns (float) 0.0 if less than 5 map times (kztimer calculates the avg time on mapstart and if someone set a new time) 
native Float:KZTimer_GetAvgTimePro(); //avg pro time - returns (float) 0.0 if less than 5 map times (kztimer calculates the avg time on mapstart and if someone set a new time)
native KZTimer_GetSkillGroup(client); // skill group - returns (int) 0=NORANK, 1=NEWB,2=SCRUB,..,9=PRO 
//KZTimer_GetSkillGroup can be helpful to set up a high ranked only server. This server has to share the database with your 'main' kztimer server
public SharedPlugin:__pl_KZTimer =
{
	name = "KZTimer",
	file = "KZTimer.smx",
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
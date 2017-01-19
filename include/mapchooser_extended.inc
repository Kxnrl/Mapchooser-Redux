#include <mapchooser>

enum CanNominateResult
{
	CanNominate_No_VoteFull,		/** No, nominations list is full */
	CanNominate_No_VoteInProgress,	/** No, map vote is in progress */
	CanNominate_No_VoteComplete,	/** No, map vote is completed */
	CanNominate_Yes,				/** Yes, you can nominate */
};


/**
 * Called whenever warning timer starts
 * 
 */
forward OnMapVoteWarningStart();

/**
 * Called whenever runoff warning timer starts
 */
forward OnMapVoteRunnoffWarningStart();

/**
 * Called whenever the timer ticks
 */
forward OnMapVoteWarningTick(time);

/**
 * Called whenever vote starts
 * 
 * @deprecated Will be removed in MapChooser 1.8.  Use OnMapVoteStarted instead.
 */
forward OnMapVoteStart();

/**
 * Called whenever vote ends
 */
forward OnMapVoteEnd(const String:map[]);

/**
 * Is a map on the current game's official list?
 * This should be treated as informative only.
 * 
 * @param map 	Name of map to check
 * @return 		true if it's on the list of official maps for this game
 */
native bool:IsMapOfficial(const String:map[]);

/**
 * Is nominate allowed?
 * 
 * @return		A CanNominateResult corresponding to whether a vote is allowed or not
 */
native CanNominateResult:CanNominate();
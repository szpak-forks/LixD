module game.model.state;

/* A gamestate. It saves everything about the current position, but not
 * how we got here. The class Replay saves everything about the history,
 * so you can reconstruct the current state from the beginning gamestate and
 * a replay.
 *
 * StateManager holds many states, and knows when to auto-save.
 * Feed the StateManager with the current state all the time, it will do
 * nothing most of the time with the state fed.
 */

import std.range;
import std.algorithm;
import core.memory; // GC.collect();

import basics.help; // clone(T[]), a deep copy for arrays
import basics.nettypes;
import basics.topology;
import tile.phymap;
import game.tribe;
import game.replay;
import graphic.torbit;
import graphic.gadget;
import hardware.tharsis;

import std.string; // format

class GameState {

    Update update;
    int  clock;
    bool clockIsRunning;

    bool goalsLocked; // in singleplayer, when time has run out

    Tribe[] tribes;

    Hatch[] hatches;
    Goal[] goals;
    Gadget[] decos;
    Water[] waters;
    TrapTrig[] traps;
    Flinger[] flingers;

    Torbit land;
    Phymap lookup;

    this() { }
/*  this         (in GameState rhs);
 *  void copyFrom(in GameState rhs);
 */
    GameState clone() const { return new GameState(this); }

    void foreachGadget(void delegate(Gadget) func)
    {
        chain(hatches, goals, decos, waters, traps, flingers)
            .each!func;
    }
    // It's sad that I need the duplication of this function, but inout
    // didn't work with delegates. No idea if it's me or D.
    void foreachConstGadget(void delegate(const Gadget) func) const
    {
        foreach (g; hatches) func(g);
        foreach (g; goals) func(g);
        foreach (g; decos) func(g);
        foreach (g; waters) func(g);
        foreach (g; traps) func(g);
        foreach (g; flingers) func(g);
    }

    @property bool multiplayer() const
    {
        assert (tribes.length > 0);
        return (tribes.length > 1);
    }

    @property bool singlePlayerHasWon() const
    {
        return ! multiplayer && tribes[0].lixSaved >= tribes[0].lixRequired;
    }

    private void
    copyValuesArraysFrom(in GameState rhs)
    {
        update         = rhs.update;
        clock          = rhs.clock;
        clockIsRunning = rhs.clockIsRunning;
        goalsLocked    = rhs.goalsLocked;

        tribes   = rhs.tribes  .clone;
        hatches  = rhs.hatches .clone;
        goals    = rhs.goals   .clone;
        decos    = rhs.decos   .clone;
        waters   = rhs.waters  .clone;
        traps    = rhs.traps   .clone;
        flingers = rhs.flingers.clone;
    }

    this(in GameState rhs)
    {
        assert (rhs, "don't copy-construct from a null GameState");
        assert (rhs.land, "don't copy-construct from GameState without land");

        copyValuesArraysFrom(rhs);
        land   = new Torbit(rhs.land);
        lookup = new Phymap(rhs.lookup);
    }

    void copyFrom(in GameState rhs)
    {
        assert (rhs);
        assert (rhs.land);
        assert (this.land);
        assert (rhs.land.Topology.opEquals(this.land),
            "for fast copyFrom, we want to avoid newing Albits, we only blit");

        copyValuesArraysFrom(rhs);
        land  .copyFrom(rhs.land);
        lookup.copyFrom(rhs.lookup);
    }

    // currently unnused, shall be used by StateManager and Game's cs
    static void cloneOrCopyFrom(ref GameState lhs, in GameState rhs)
    {
        if (lhs is null)
            lhs = new GameState(rhs);
        else
            lhs.copyFrom(rhs);
    }

}
// end class GameState



// ############################################################################
// ############################################################################
// ############################################################################



class StateManager {

private:

    enum updatesMostFrequentPair = 10;
    enum updatesMultiplierNextPairIsSlowerBy = 5; // 10, 50, 250, 1250
    enum pairsToKeep = 4;

    GameState _zero;
    GameState _userState;
    GameState[2 * pairsToKeep] _auto;

    // For the user-triggered save (_user), remember the replay that was
    // correct by then. Otherwise, the user could restart, do something
    // deviating, and then load the user state that supposes the old,
    // differing replay.
    Replay _userReplay;

public:

    void saveZero(in GameState s) { _zero = s.clone(); }

    void saveUser(in GameState s, in Replay r)
    {
        _userState  = s.clone();
        assert (r);
        if (_userReplay is null || ! r.isSubsetOf(_userReplay))
            _userReplay = r.clone();
    }

    @property const(GameState) zeroState()  const { return _zero;       }
    @property const(GameState) userState()  const { return _userState;  }
    @property const(Replay)    userReplay() const { return _userReplay; }

    GameState autoBeforeUpdate(in int u)
    {
        assert (zeroState, "need _zero as a fallback for autoBeforeUpdate");
        GameState ret = _zero;
        foreach (ref GameState candidate; _auto)
            if (   candidate !is null
                && candidate.update < u
                && candidate.update > ret.update
            ) {
                ret = candidate;
            }

        foreach (ref GameState possibleGarbage; _auto)
            if (possibleGarbage && possibleGarbage.update >= u)
                // DTODO: find out whether we should manually destroy the
                // torbit and lookup matrix here, and then garbage-collect
                possibleGarbage = null;
        version (tharsisprofiling)
            auto zone = Zone(profiler, "GC in autoBeforeUpdate");
        core.memory.GC.collect();
        return ret;
    }

    int updateMultipleForPair(in int pair) const pure
    {
        assert (pair >= 0 && pair < pairsToKeep);
        int ret = updatesMostFrequentPair;
        foreach (i; 0 .. pair)
            ret *= updatesMultiplierNextPairIsSlowerBy;
        return ret;
    }

    alias wouldAutoSave            = wouldAutoSaveTpl!0;
    alias wouldAutoSaveDuringTurbo = wouldAutoSaveTpl!1;

    void autoSave(in GameState s, in Update ultimatelyTo)
    {
        if (! wouldAutoSave(s, ultimatelyTo))
            return;
        scope (success) {
            version (tharsisprofiling)
                auto zone = Zone(profiler, "GC in autoSave");
            core.memory.GC.collect();
        }
        // Potentially push older auto-saved states down the hierarchy.
        // First, if it's time to copy a frequent state into a less frequent
        // state, make these copies. Start with least frequent copying the
        // second-to-least freqent.
        // After copying the internal states like that, save s into the most
        // frequently updated pair. The most frequently updated pair has
        // array indices 0 and 1. The next one has array indices 2 and 3, ...
        for (int pair = pairsToKeep - 1; pair >= 0; --pair) {
            immutable int umfp = updateMultipleForPair(pair);
            if (s.update % umfp == 0) {
                int whichOfPair = (s.update / umfp) % 2;
                if (pair > 0) {
                    // make a shallow copy, because we treat states inside
                    // the save manager like immutable data. If the thing
                    // to copy is null, don't copy it, because we might
                    // currently hold good data that is old, and the newer
                    // data to copy was set to null because it's a wrong
                    // timeline.
                    GameState moreFrequentToCopy = _auto[2*(pair-1)];
                    if (moreFrequentToCopy is null)
                        moreFrequentToCopy = _auto[2*(pair-1) + 1];
                    if (moreFrequentToCopy !is null)
                        _auto[2*pair + whichOfPair] = moreFrequentToCopy;
                }
                else {
                    // make a hard copy of the current state
                    _auto[0 + whichOfPair] = s.clone();
                }
            }
        }
    }
    // end function calcSaveAuto

private:
    bool wouldAutoSaveTpl(int pair)(in GameState s, in Update updTo) const pure
        if (pair >= 0 && pair < pairsToKeep)
    {
        if (! s || s.update == 0
                || s.update % updateMultipleForPair(pair) != 0)
            return false;
        foreach (possible; pair .. pairsToKeep)
            // We save 2 states per update multiple. But when we want to update
            // 100 times, there is no need saving states after 10, 20, 30, ...
            // updates, we would only keep the states at 90 and 100, anyway.
            // And the state at 50 and 100, in a higher pair.
            if (s.update > updTo - 2 * updateMultipleForPair(possible)
                && s.update % updateMultipleForPair(possible) == 0)
                return true;
        return false;
    }
}
// end class StateManager

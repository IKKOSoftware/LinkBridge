//
//  s8link.cpp
//  CLink
//
//  See s8link.h. Uses the app-thread session state throughout: the bridge captures the timeline from its own
//  threads, not an audio callback.
//

#include "s8link.h"

#include <ableton/Link.hpp>

#include <chrono>

struct s8link {
    explicit s8link(double bpm) : link(bpm) {}
    ableton::Link link;
};

namespace {
std::chrono::microseconds micros(int64_t value) {
    return std::chrono::microseconds(value);
}
}

extern "C" {

s8link *s8link_create(double bpm) {
    return new s8link(bpm);
}

void s8link_destroy(s8link *link) {
    delete link;
}

void s8link_enable(s8link *link, bool enabled) {
    link->link.enable(enabled);
}

bool s8link_is_enabled(s8link *link) {
    return link->link.isEnabled();
}

void s8link_enable_start_stop_sync(s8link *link, bool enabled) {
    link->link.enableStartStopSync(enabled);
}

bool s8link_is_start_stop_sync_enabled(s8link *link) {
    return link->link.isStartStopSyncEnabled();
}

uint64_t s8link_num_peers(s8link *link) {
    return link->link.numPeers();
}

int64_t s8link_clock_micros(s8link *link) {
    return link->link.clock().micros().count();
}

s8link_state s8link_capture(s8link *link, int64_t at_micros, double quantum) {
    const auto state = link->link.captureAppSessionState();
    s8link_state result;
    result.tempo = state.tempo();
    result.beat = state.beatAtTime(micros(at_micros), quantum);
    result.phase = state.phaseAtTime(micros(at_micros), quantum);
    result.is_playing = state.isPlaying();
    return result;
}

int64_t s8link_time_at_beat(s8link *link, double beat, double quantum) {
    return link->link.captureAppSessionState().timeAtBeat(beat, quantum).count();
}

void s8link_set_tempo(s8link *link, double bpm, int64_t at_micros) {
    auto state = link->link.captureAppSessionState();
    state.setTempo(bpm, micros(at_micros));
    link->link.commitAppSessionState(state);
}

void s8link_set_playing(s8link *link, bool playing, int64_t at_micros) {
    auto state = link->link.captureAppSessionState();
    state.setIsPlaying(playing, micros(at_micros));
    link->link.commitAppSessionState(state);
}

}

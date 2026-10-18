//
//  s8link.h
//  CLink
//
//  A small C interface to Ableton Link (vendor/link, GPL v2+), the part of LinkBridge
//  that talks to Link, with just what it needs: tempo, the beat timeline and start/stop. Times are
//  Link's clock, in microseconds.
//

#ifndef S8LINK_H
#define S8LINK_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct s8link s8link;

/// The session as captured at a moment.
typedef struct s8link_state {
    double tempo;
    /// Beats on the shared timeline.
    double beat;
    /// Where in the bar (0 to quantum).
    double phase;
    bool is_playing;
} s8link_state;

s8link *s8link_create(double bpm);
void s8link_destroy(s8link *link);

void s8link_enable(s8link *link, bool enabled);
bool s8link_is_enabled(s8link *link);
void s8link_enable_start_stop_sync(s8link *link, bool enabled);
bool s8link_is_start_stop_sync_enabled(s8link *link);
uint64_t s8link_num_peers(s8link *link);

int64_t s8link_clock_micros(s8link *link);

s8link_state s8link_capture(s8link *link, int64_t at_micros, double quantum);
/// The time a beat falls at, for waiting on it.
int64_t s8link_time_at_beat(s8link *link, double beat, double quantum);
void s8link_set_tempo(s8link *link, double bpm, int64_t at_micros);
/// Shares starting or stopping with the session (when start/stop sync is on).
void s8link_set_playing(s8link *link, bool playing, int64_t at_micros);

#ifdef __cplusplus
}
#endif

#endif

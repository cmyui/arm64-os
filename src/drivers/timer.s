// ARM64 Generic Timer Access
// Reads cycle counter and frequency from system registers

.section .text
.global timer_read
.global timer_freq

// timer_read: Read the physical counter
// Output: x0 = current counter value
timer_read:
    mrs x0, cntpct_el0
    ret

// timer_freq: Read the counter frequency
// Output: x0 = frequency in Hz
timer_freq:
    mrs x0, cntfrq_el0
    ret

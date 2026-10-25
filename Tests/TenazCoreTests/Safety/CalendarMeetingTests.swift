import Testing
@testable import TenazCore

struct CalendarMeetingTests {
    @Test func timeBlocksWithoutAttendeesAreNotMeetings() {
        // All-day personal time blocks ("Sleep", "Shower", a conference) with no attendees.
        #expect(!CalendarMeeting.isMeeting(otherAttendees: 0, texts: ["Sleep", nil, nil, nil]))
        #expect(!CalendarMeeting.isMeeting(otherAttendees: 0, texts: ["Conference", "Convention Center", "", nil]))
    }

    @Test func attendeesOrCallLinksAreMeetings() {
        #expect(CalendarMeeting.isMeeting(otherAttendees: 1, texts: ["1:1"]))
        #expect(CalendarMeeting.isMeeting(otherAttendees: 0, texts: ["Sync", nil, "Microsoft Teams Meeting", "Join: https://teams.microsoft.com/l/meetup-join/abc"]))
        #expect(CalendarMeeting.isMeeting(otherAttendees: 0, texts: ["Call", "https://us02web.ZOOM.us/j/123", nil, nil]))
        #expect(CalendarMeeting.isMeeting(otherAttendees: 0, texts: ["Standup", nil, "https://meet.google.com/abc-defg-hij", nil]))
    }
}

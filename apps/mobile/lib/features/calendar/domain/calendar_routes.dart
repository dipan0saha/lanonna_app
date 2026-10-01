abstract final class CalendarRoutes {
  static const calendar = '/calendar';
  static const createEvent = '/calendar/event/create';
  static const aiSuggestions = '/calendar/ai-suggestions';

  static String eventDetail(String eventId) => '/calendar/event/$eventId';
  static String eventEdit(String eventId) => '/calendar/event/$eventId/edit';
}

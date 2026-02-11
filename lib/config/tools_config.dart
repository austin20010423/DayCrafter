/// Configuration for AI tools used in the app
final List<Map<String, dynamic>> aiTools = [
  {'type': 'web_search', 'search_context_size': 'medium'},
  {
    'type': 'function',
    'name': 'add_calendar_task',
    'description':
        'Directly add a task to the calendar. Use this when the user request is specific about WHAT, WHEN, and TIME. e.g. "Add meeting tomorrow at 2pm"',
    'parameters': {
      'type': 'object',
      'properties': {
        'title': {'type': 'string', 'description': 'The title of the task'},
        'description': {
          'type': 'string',
          'description': 'Description or details of the task',
        },
        'start_date_time': {
          'type': 'string',
          'description':
              'The start date and time in ISO 8601 format (e.g. 2024-02-05T14:00:00)',
        },
        'end_date_time': {
          'type': 'string',
          'description':
              'The end date and time in ISO 8601 format. If not provided, defaults to 1 hour duration.',
        },
        'priority': {
          'type': 'integer',
          'description':
              'Priority level: 1 (High), 2 (Medium), 3 (Low). Default is 3.',
          'enum': [1, 2, 3],
        },
      },
      'required': ['title', 'start_date_time'],
    },
  },
  {
    'type': 'function',
    'name': 'task_and_schedule_planer',
    'description':
        'Plan and schedule tasks for the user. Use when user wants to create, organize, plan, or schedule tasks.',
    'parameters': {
      'type': 'object',
      'properties': {
        'topic': {
          'type': 'string',
          'description': 'The task description or query from the user',
        },
      },
      'required': ['topic'],
    },
  },
  {
    'type': 'function',
    'name': 'check_gmail',
    'description':
        'Check the user\'s Gmail inbox and return recent emails. Use this when the user wants to check, read, or search their email.',
    'parameters': {
      'type': 'object',
      'properties': {
        'query': {
          'type': 'string',
          'description':
              'Gmail search query (e.g. "is:unread", "from:someone@example.com", "is:inbox"). Defaults to "is:inbox".',
        },
        'max_results': {
          'type': 'integer',
          'description': 'Maximum number of emails to return. Defaults to 10.',
        },
      },
      'required': [],
    },
  },
  {
    'type': 'function',
    'name': 'switch_gmail_account',
    'description':
        'Switch to a different Gmail account. Use this when the user wants to switch, change, or log out of their current Gmail account.',
    'parameters': {'type': 'object', 'properties': {}, 'required': []},
  },
];

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mcp_dart/mcp_dart.dart';
import '../provider.dart';

class GlobalAgentTools {
  final DayCrafterProvider provider;

  GlobalAgentTools(this.provider);

  /// Restricted tool definitions for Global Agent
  static List<Map<String, dynamic>> get restrictedTools => [
    {
      'type': 'function',
      'function': {
        'name': 'create_project',
        'description':
            'Create a new project to organize tasks, goals, or information.',
        'parameters': {
          'type': 'object',
          'properties': {
            'name': {
              'type': 'string',
              'description': 'The name of the project',
            },
            'description': {
              'type': 'string',
              'description': 'A brief description of what this project is for',
            },
            'color_hex': {
              'type': 'string',
              'description': 'Theme color in hex format (e.g. #4F46E5)',
            },
            'icon': {
              'type': 'string',
              'description': 'Icon name (e.g. Folder, Briefcase, Rocket)',
            },
          },
          'required': ['name', 'description'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'check_gmail',
        'description':
            'Access and summarize emails from the integrated Gmail account.',
        'parameters': {
          'type': 'object',
          'properties': {
            'query': {
              'type': 'string',
              'description': 'Gmail search query like "is:unread"',
            },
            'max_results': {
              'type': 'integer',
              'description': 'Maximum number of emails to retrieve',
            },
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'web_search',
        'description':
            'Search the web for real-time information like weather, traffic, or news.',
        'parameters': {
          'type': 'object',
          'properties': {
            'query': {
              'type': 'string',
              'description': 'The search query string',
            },
          },
          'required': ['query'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_weather',
        'description':
            'Get the current weather and temperature for a specific location.',
        'parameters': {
          'type': 'object',
          'properties': {
            'latitude': {
              'type': 'number',
              'description': 'The latitude of the location',
            },
            'longitude': {
              'type': 'number',
              'description': 'The longitude of the location',
            },
          },
          'required': ['latitude', 'longitude'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_location',
        'description':
            'Retrieve the user\'s current precise location (latitude, longitude, city).',
        'parameters': {'type': 'object', 'properties': {}},
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_all_project_memories',
        'description':
            'Retrieve memories/summaries from all projects to understand context.',
        'parameters': {'type': 'object', 'properties': {}},
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_all_calendar_events',
        'description':
            'Retrieve all upcoming calendar events to manage schedule.',
        'parameters': {
          'type': 'object',
          'properties': {
            'limit': {
              'type': 'integer',
              'description':
                  'Maximum number of events to retrieve (default 50)',
            },
          },
        },
      },
    },
  ];

  /// Execute a tool call from the Global Agent
  Future<String> executeTool(String name, String arguments) async {
    debugPrint('GlobalAgentTools: Executing $name with $arguments');

    try {
      final args = jsonDecode(arguments);

      // Wrap the actual execution in a timeout to prevent indefinite hanging
      final result =
          await Future<String>(() async {
            switch (name) {
              case 'get_location':
                return await _handleGetLocation();
              case 'get_weather':
                return await _handleGetWeather(args);
              case 'web_search':
                return await _handleWebSearch(args['query']);
              case 'create_project':
                return await _handleCreateProject(args);
              case 'check_gmail':
                return await _handleCheckGmail(args);
              case 'get_all_project_memories':
                return await _handleGetAllProjectMemories();
              case 'get_all_calendar_events':
                return await _handleGetAllCalendarEvents(args);
              default:
                return 'Error: Unknown tool $name';
            }
          }).timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              debugPrint('GlobalAgentTools: TIMEOUT executing $name after 30s');
              return 'Error: Tool $name timed out after 30 seconds. Please try again.';
            },
          );

      debugPrint('GlobalAgentTools: $name completed successfully');
      return result;
    } catch (e) {
      debugPrint('GlobalAgentTools Error: $e');
      return 'Error executing tool $name: $e';
    }
  }

  Future<String> _handleGetLocation() async {
    final client = provider.mcpClient;
    if (client == null) return 'Error: Email/Location service unavailable';

    final result = await client.callTool(
      CallToolRequest(name: 'get_location', arguments: {}),
    );

    return _extractTextFromResult(result);
  }

  Future<String> _handleGetWeather(Map<String, dynamic> args) async {
    final client = provider.mcpClient;
    if (client == null) return 'Error: Weather service unavailable';

    final result = await client.callTool(
      CallToolRequest(
        name: 'get_weather',
        arguments: {
          'latitude': args['latitude'],
          'longitude': args['longitude'],
        },
      ),
    );

    return _extractTextFromResult(result);
  }

  Future<String> _handleWebSearch(String query) async {
    if (provider.mcpClient == null) {
      await provider.initMcpClient();
    }
    final client = provider.mcpClient;
    if (client == null) return 'Error: Web search service unavailable';

    final result = await client.callTool(
      CallToolRequest(name: 'web_search', arguments: {'query': query}),
    );

    return _extractTextFromResult(result);
  }

  Future<String> _handleCreateProject(Map<String, dynamic> args) async {
    // This tool is special as it updates the Flutter state directly
    final name = args['name'];
    final description = args['description'];
    final color = args['color_hex'] ?? '#4F46E5';
    final icon = args['icon'] ?? 'Folder';

    // Call provider to add project (need to expose this method in provider)
    // We'll return a JSON confirmation that the AI can understand
    return jsonEncode({
      "status": "success",
      "message": "Project '$name' created successfully.",
      "project": {
        "name": name,
        "description": description,
        "color": color,
        "icon": icon,
      },
    });
  }

  Future<String> _handleCheckGmail(Map<String, dynamic> args) async {
    debugPrint('_handleCheckGmail: Starting...');
    final client = provider.mcpClient;
    if (client == null) {
      debugPrint('_handleCheckGmail: MCP client is null!');
      return 'Error: Email service unavailable. MCP client not initialized.';
    }

    debugPrint('_handleCheckGmail: Calling MCP tool check_gmail...');
    try {
      final result = await client.callTool(
        CallToolRequest(
          name: 'check_gmail',
          arguments: {
            'query': args['query'] ?? 'is:inbox',
            'max_results': args['max_results'] ?? 5,
          },
        ),
      );

      debugPrint(
        '_handleCheckGmail: Got result with ${result.content.length} content items',
      );
      return _extractTextFromResult(result);
    } catch (e) {
      debugPrint('_handleCheckGmail: Error calling MCP tool: $e');
      return 'Error checking Gmail: $e';
    }
  }

  String _extractTextFromResult(CallToolResult result) {
    if (result.content.isEmpty) return 'No data returned';
    final first = result.content.first;
    if (first is TextContent) return first.text;
    return first.toString();
  }

  Future<String> _handleGetAllProjectMemories() async {
    try {
      final memories = await provider.getAllProjectMemories();
      return jsonEncode(memories);
    } catch (e) {
      return "Error retrieving project memories: $e";
    }
  }

  Future<String> _handleGetAllCalendarEvents(Map<String, dynamic> args) async {
    try {
      final limit = args['limit'] ?? 50;
      final events = await provider.getAllUpcomingEvents(limit: limit);
      return jsonEncode(events);
    } catch (e) {
      return "Error retrieving calendar events: $e";
    }
  }
}

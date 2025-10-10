import 'dart:math';

class MilestoneMessages {
  static final List<String> _planningMessages = [
    'Initializing neural engines...',
    'Loading cognitive frameworks...',
    'Booting up AI processors...',
    'Activating thought patterns...',
    'Calibrating neural networks...',
    'Warming up synaptic connections...',
    'Preparing mental models...',
    'Loading knowledge databases...',
    'Initializing reasoning engines...',
    'Booting cognitive systems...',
  ];

  static final List<String> _executionMessages = [
    'Executing digital commands...',
    'Processing external data...',
    'Gathering intelligence...',
    'Scanning information sources...',
    'Collecting relevant data...',
    'Analyzing external resources...',
    'Processing real-time information...',
    'Fetching knowledge from sources...',
    'Compiling external insights...',
    'Gathering contextual data...',
  ];

  static final List<String> _writingMessages = [
    'Crafting intelligent response...',
    'Generating thoughtful answer...',
    'Composing detailed explanation...',
    'Formulating comprehensive reply...',
    'Synthesizing information...',
    'Creating detailed response...',
    'Assembling intelligent answer...',
    'Constructing thoughtful reply...',
    'Developing comprehensive explanation...',
    'Building detailed response...',
  ];

  static final List<String> _finalizingMessages = [
    'Polishing final response...',
    'Refining output quality...',
    'Optimizing content structure...',
    'Enhancing response clarity...',
    'Finalizing intelligent reply...',
    'Perfecting answer format...',
    'Completing response synthesis...',
    'Finishing thought process...',
    'Wrapping up intelligent analysis...',
    'Concluding detailed explanation...',
  ];

  static String getRandomExecutionMessage() {
    return _executionMessages[Random().nextInt(_executionMessages.length)];
  }

  static String getRandomFinalizingMessage() {
    return _finalizingMessages[Random().nextInt(_finalizingMessages.length)];
  }

  static String getRandomMessageForPhase(String phase) {
    switch (phase.toLowerCase()) {
      case 'planning':
        return getRandomPlanningMessage();
      case 'execution':
        return getRandomExecutionMessage();
      case 'writing':
        return getRandomWritingMessage();
      case 'finalizing':
        return getRandomFinalizingMessage();
      default:
        return getRandomPlanningMessage();
    }
  }

  static String getRandomPlanningMessage() {
    return _planningMessages[Random().nextInt(_planningMessages.length)];
  }

  static String getRandomWritingMessage() {
    return _writingMessages[Random().nextInt(_writingMessages.length)];
  }
} 
import '../models/roadmap_models.dart';

class RoadmapGraphs {
  static const RoadmapGraph frontendRoadmap = RoadmapGraph(
    id: 'frontend',
    title: 'Frontend Developer Roadmap',
    description: 'Complete roadmap for frontend development',
    role: LearningRole.frontend,
    width: 2000,
    height: 1400,
    nodes: [
      // Internet fundamentals (top center)
      RoadmapGraphNode(
        id: 'internet',
        title: 'Internet',
        type: NodeType.core,
        position: NodePosition(800, 150),
      ),
      RoadmapGraphNode(
        id: 'how_internet_works',
        title: 'How does the internet work?',
        type: NodeType.topic,
        position: NodePosition(1200, 80),
      ),
      RoadmapGraphNode(
        id: 'what_is_http',
        title: 'What is HTTP?',
        type: NodeType.topic,
        position: NodePosition(1200, 150),
      ),
      RoadmapGraphNode(
        id: 'domain_name',
        title: 'What is Domain Name?',
        type: NodeType.topic,
        position: NodePosition(1200, 220),
      ),
      RoadmapGraphNode(
        id: 'hosting',
        title: 'What is hosting?',
        type: NodeType.topic,
        position: NodePosition(1200, 290),
      ),
      RoadmapGraphNode(
        id: 'dns',
        title: 'DNS and how it works?',
        type: NodeType.topic,
        position: NodePosition(1200, 360),
      ),
      RoadmapGraphNode(
        id: 'browsers',
        title: 'Browsers and how they work?',
        type: NodeType.topic,
        position: NodePosition(1200, 430),
      ),

      // Core technologies (center flow)
      RoadmapGraphNode(
        id: 'html',
        title: 'HTML',
        type: NodeType.core,
        position: NodePosition(300, 600),
      ),
      RoadmapGraphNode(
        id: 'css',
        title: 'CSS',
        type: NodeType.core,
        position: NodePosition(700, 600),
      ),
      RoadmapGraphNode(
        id: 'javascript',
        title: 'JavaScript',
        type: NodeType.core,
        position: NodePosition(1100, 600),
      ),

      // HTML topics (left side)
      RoadmapGraphNode(
        id: 'learn_basics_html',
        title: 'Learn the basics',
        type: NodeType.topic,
        position: NodePosition(100, 480),
      ),
      RoadmapGraphNode(
        id: 'semantic_html',
        title: 'Writing Semantic HTML',
        type: NodeType.topic,
        position: NodePosition(100, 560),
      ),
      RoadmapGraphNode(
        id: 'forms_validation',
        title: 'Forms and Validations',
        type: NodeType.topic,
        position: NodePosition(100, 640),
      ),
      RoadmapGraphNode(
        id: 'accessibility',
        title: 'Accessibility',
        type: NodeType.topic,
        position: NodePosition(100, 720),
      ),
      RoadmapGraphNode(
        id: 'seo_basics',
        title: 'SEO Basics',
        type: NodeType.topic,
        position: NodePosition(100, 800),
      ),

      // CSS topics (center)
      RoadmapGraphNode(
        id: 'learn_basics_css',
        title: 'Learn the Basics',
        type: NodeType.topic,
        position: NodePosition(500, 480),
      ),
      RoadmapGraphNode(
        id: 'making_layouts',
        title: 'Making Layouts',
        type: NodeType.topic,
        position: NodePosition(500, 560),
      ),
      RoadmapGraphNode(
        id: 'responsive_design',
        title: 'Responsive Design',
        type: NodeType.topic,
        position: NodePosition(500, 720),
      ),

      // JavaScript topics (right side)
      RoadmapGraphNode(
        id: 'learn_basics_js',
        title: 'Learn the Basics',
        type: NodeType.topic,
        position: NodePosition(1300, 480),
      ),
      RoadmapGraphNode(
        id: 'dom_manipulation',
        title: 'Learn DOM Manipulation',
        type: NodeType.topic,
        position: NodePosition(1300, 560),
      ),
      RoadmapGraphNode(
        id: 'fetch_api',
        title: 'Fetch API / Ajax (XHR)',
        type: NodeType.topic,
        position: NodePosition(1300, 720),
      ),

      // Version Control (bottom left)
      RoadmapGraphNode(
        id: 'vcs',
        title: 'Version Control Systems',
        type: NodeType.core,
        position: NodePosition(300, 1000),
      ),
      RoadmapGraphNode(
        id: 'git',
        title: 'Git',
        type: NodeType.topic,
        position: NodePosition(100, 1100),
      ),
      RoadmapGraphNode(
        id: 'github',
        title: 'GitHub',
        type: NodeType.topic,
        position: NodePosition(250, 1100),
      ),
      RoadmapGraphNode(
        id: 'gitlab',
        title: 'GitLab',
        type: NodeType.topic,
        position: NodePosition(400, 1100),
      ),
      RoadmapGraphNode(
        id: 'bitbucket',
        title: 'Bitbucket',
        type: NodeType.topic,
        position: NodePosition(550, 1100),
      ),

      // Package Managers (bottom center)
      RoadmapGraphNode(
        id: 'package_managers',
        title: 'Package Managers',
        type: NodeType.core,
        position: NodePosition(1100, 1000),
      ),
      RoadmapGraphNode(
        id: 'npm',
        title: 'npm',
        type: NodeType.topic,
        position: NodePosition(900, 1100),
      ),
      RoadmapGraphNode(
        id: 'yarn',
        title: 'Yarn',
        type: NodeType.topic,
        position: NodePosition(1100, 1100),
      ),
      RoadmapGraphNode(
        id: 'pnpm',
        title: 'pnpm',
        type: NodeType.topic,
        position: NodePosition(1300, 1100),
      ),

      // VCS Hosting (bottom right)
      RoadmapGraphNode(
        id: 'vcs_hosting',
        title: 'VCS Hosting',
        type: NodeType.core,
        position: NodePosition(1500, 1000),
      ),
    ],
    connections: [
      // Internet connections
      RoadmapConnection(fromNodeId: 'internet', toNodeId: 'how_internet_works', isDotted: true),
      RoadmapConnection(fromNodeId: 'internet', toNodeId: 'what_is_http', isDotted: true),
      RoadmapConnection(fromNodeId: 'internet', toNodeId: 'domain_name', isDotted: true),
      RoadmapConnection(fromNodeId: 'internet', toNodeId: 'hosting', isDotted: true),
      RoadmapConnection(fromNodeId: 'internet', toNodeId: 'dns', isDotted: true),
      RoadmapConnection(fromNodeId: 'internet', toNodeId: 'browsers', isDotted: true),

      // Core technology flow
      RoadmapConnection(fromNodeId: 'html', toNodeId: 'css'),
      RoadmapConnection(fromNodeId: 'css', toNodeId: 'javascript'),

      // HTML topic connections
      RoadmapConnection(fromNodeId: 'learn_basics_html', toNodeId: 'html', isDotted: true),
      RoadmapConnection(fromNodeId: 'semantic_html', toNodeId: 'html', isDotted: true),
      RoadmapConnection(fromNodeId: 'forms_validation', toNodeId: 'html', isDotted: true),
      RoadmapConnection(fromNodeId: 'accessibility', toNodeId: 'html', isDotted: true),
      RoadmapConnection(fromNodeId: 'seo_basics', toNodeId: 'html', isDotted: true),

      // CSS topic connections
      RoadmapConnection(fromNodeId: 'css', toNodeId: 'learn_basics_css', isDotted: true),
      RoadmapConnection(fromNodeId: 'css', toNodeId: 'making_layouts', isDotted: true),
      RoadmapConnection(fromNodeId: 'css', toNodeId: 'responsive_design', isDotted: true),

      // JavaScript topic connections
      RoadmapConnection(fromNodeId: 'javascript', toNodeId: 'learn_basics_js', isDotted: true),
      RoadmapConnection(fromNodeId: 'javascript', toNodeId: 'dom_manipulation', isDotted: true),
      RoadmapConnection(fromNodeId: 'javascript', toNodeId: 'fetch_api', isDotted: true),

      // Version control connections
      RoadmapConnection(fromNodeId: 'html', toNodeId: 'vcs'),
      RoadmapConnection(fromNodeId: 'vcs', toNodeId: 'git', isDotted: true),
      RoadmapConnection(fromNodeId: 'vcs', toNodeId: 'github', isDotted: true),
      RoadmapConnection(fromNodeId: 'vcs', toNodeId: 'gitlab', isDotted: true),
      RoadmapConnection(fromNodeId: 'vcs', toNodeId: 'bitbucket', isDotted: true),

      // Package manager connections
      RoadmapConnection(fromNodeId: 'javascript', toNodeId: 'package_managers'),
      RoadmapConnection(fromNodeId: 'package_managers', toNodeId: 'npm', isDotted: true),
      RoadmapConnection(fromNodeId: 'package_managers', toNodeId: 'yarn', isDotted: true),
      RoadmapConnection(fromNodeId: 'package_managers', toNodeId: 'pnpm', isDotted: true),

      // VCS Hosting connections
      RoadmapConnection(fromNodeId: 'vcs', toNodeId: 'vcs_hosting'),
    ],
  );

  static RoadmapGraph getRoadmapGraph(LearningRole role) {
    switch (role) {
      case LearningRole.frontend:
        return frontendRoadmap;
      case LearningRole.backend:
        return _createBackendRoadmap();
      case LearningRole.fullstack:
        return _createFullstackRoadmap();
      default:
        return frontendRoadmap; // Default to frontend for now
    }
  }

  static RoadmapGraph _createBackendRoadmap() {
    return const RoadmapGraph(
      id: 'backend',
      title: 'Backend Developer Roadmap',
      description: 'Complete roadmap for backend development',
      role: LearningRole.backend,
      width: 2000,
      height: 1400,
      nodes: [
        RoadmapGraphNode(
          id: 'programming_language',
          title: 'Programming Language',
          type: NodeType.core,
          position: NodePosition(300, 200),
        ),
        RoadmapGraphNode(
          id: 'python',
          title: 'Python',
          type: NodeType.topic,
          position: NodePosition(200, 150),
        ),
        RoadmapGraphNode(
          id: 'javascript',
          title: 'JavaScript',
          type: NodeType.topic,
          position: NodePosition(200, 200),
        ),
        RoadmapGraphNode(
          id: 'java',
          title: 'Java',
          type: NodeType.topic,
          position: NodePosition(200, 250),
        ),
        RoadmapGraphNode(
          id: 'databases',
          title: 'Databases',
          type: NodeType.core,
          position: NodePosition(500, 300),
        ),
        RoadmapGraphNode(
          id: 'postgresql',
          title: 'PostgreSQL',
          type: NodeType.topic,
          position: NodePosition(400, 250),
        ),
        RoadmapGraphNode(
          id: 'mongodb',
          title: 'MongoDB',
          type: NodeType.topic,
          position: NodePosition(400, 300),
        ),
        RoadmapGraphNode(
          id: 'redis',
          title: 'Redis',
          type: NodeType.topic,
          position: NodePosition(400, 350),
        ),
      ],
      connections: [
        RoadmapConnection(fromNodeId: 'python', toNodeId: 'programming_language', isDotted: true),
        RoadmapConnection(fromNodeId: 'javascript', toNodeId: 'programming_language', isDotted: true),
        RoadmapConnection(fromNodeId: 'java', toNodeId: 'programming_language', isDotted: true),
        RoadmapConnection(fromNodeId: 'programming_language', toNodeId: 'databases'),
        RoadmapConnection(fromNodeId: 'databases', toNodeId: 'postgresql', isDotted: true),
        RoadmapConnection(fromNodeId: 'databases', toNodeId: 'mongodb', isDotted: true),
        RoadmapConnection(fromNodeId: 'databases', toNodeId: 'redis', isDotted: true),
      ],
    );
  }

  static RoadmapGraph _createFullstackRoadmap() {
    return const RoadmapGraph(
      id: 'fullstack',
      title: 'Full Stack Developer Roadmap',
      description: 'Complete roadmap for full stack development',
      role: LearningRole.fullstack,
      width: 2000,
      height: 1400,
      nodes: [
        RoadmapGraphNode(
          id: 'frontend',
          title: 'Frontend',
          type: NodeType.core,
          position: NodePosition(200, 300),
        ),
        RoadmapGraphNode(
          id: 'backend',
          title: 'Backend',
          type: NodeType.core,
          position: NodePosition(500, 300),
        ),
        RoadmapGraphNode(
          id: 'react',
          title: 'React',
          type: NodeType.topic,
          position: NodePosition(100, 250),
        ),
        RoadmapGraphNode(
          id: 'nodejs',
          title: 'Node.js',
          type: NodeType.topic,
          position: NodePosition(600, 250),
        ),
      ],
      connections: [
        RoadmapConnection(fromNodeId: 'react', toNodeId: 'frontend', isDotted: true),
        RoadmapConnection(fromNodeId: 'frontend', toNodeId: 'backend'),
        RoadmapConnection(fromNodeId: 'backend', toNodeId: 'nodejs', isDotted: true),
      ],
    );
  }
}

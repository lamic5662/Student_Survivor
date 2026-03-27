import 'package:flutter/material.dart';
import 'package:student_survivor/models/app_models.dart';

class MockData {
  static final List<Chapter> networkingChapters = [
    Chapter(
      id: 'net-1',
      title: 'OSI & TCP/IP Models',
      notes: [
        Note(
          id: 'net-note-1',
          title: 'OSI Layers Overview',
          shortAnswer:
              'OSI has 7 layers: Physical, Data Link, Network, Transport, Session, Presentation, Application.',
          detailedAnswer:
              'The OSI model divides communication into seven layers. Each layer provides services to the layer above. The Physical layer handles signals, Data Link handles framing, Network handles routing, Transport ensures end-to-end delivery, Session manages sessions, Presentation handles data formats, and Application provides user-facing services.',
        ),
        Note(
          id: 'net-note-2',
          title: 'TCP vs UDP',
          shortAnswer:
              'TCP is reliable and connection-oriented; UDP is faster and connectionless.',
          detailedAnswer:
              'TCP ensures ordered, reliable delivery using acknowledgements and retransmission. UDP sends datagrams without guarantees, making it faster for streaming or gaming. Use TCP for accuracy, UDP for speed.',
        ),
      ],
      importantQuestions: [
        Question(
          id: 'net-imp-1',
          prompt: 'Explain the OSI model with functions of each layer.',
          marks: 10,
        ),
        Question(
          id: 'net-imp-2',
          prompt: 'Differentiate between TCP and UDP with use cases.',
          marks: 5,
        ),
      ],
      pastQuestions: [
        Question(
          id: 'net-past-1',
          prompt: 'What is the role of the transport layer?',
          marks: 5,
        ),
      ],
      quizzes: [
        Quiz(
          id: 'net-quiz-1',
          title: 'OSI Rapid MCQ',
          type: QuizType.mcq,
          difficulty: QuizDifficulty.easy,
          questionCount: 10,
          duration: Duration(minutes: 10),
        ),
        Quiz(
          id: 'net-quiz-2',
          title: 'TCP vs UDP Sprint',
          type: QuizType.time,
          difficulty: QuizDifficulty.medium,
          questionCount: 8,
          duration: Duration(minutes: 6),
        ),
      ],
    ),
    Chapter(
      id: 'net-2',
      title: 'Routing & Switching',
      notes: [
        Note(
          id: 'net-note-3',
          title: 'IP Routing Basics',
          shortAnswer: 'Routers use routing tables and protocols to find paths.',
          detailedAnswer:
              'Routing is the process of selecting paths in a network. Routers maintain routing tables learned from static routes or protocols like RIP, OSPF, and BGP.',
        ),
      ],
      importantQuestions: [
        Question(
          id: 'net-imp-3',
          prompt: 'Describe routing table entries and metrics.',
          marks: 5,
        ),
      ],
      pastQuestions: [
        Question(
          id: 'net-past-2',
          prompt: 'Explain distance vector routing.',
          marks: 5,
        ),
      ],
      quizzes: [
        Quiz(
          id: 'net-quiz-3',
          title: 'Routing Challenge',
          type: QuizType.level,
          difficulty: QuizDifficulty.hard,
          questionCount: 12,
          duration: Duration(minutes: 12),
        ),
      ],
    ),
  ];

  static final List<Chapter> dbmsChapters = [
    Chapter(
      id: 'db-1',
      title: 'Relational Model',
      notes: [
        Note(
          id: 'db-note-1',
          title: 'Keys & Constraints',
          shortAnswer:
              'Primary keys uniquely identify rows; foreign keys link tables.',
          detailedAnswer:
              'Keys enforce uniqueness and relationships. Primary keys are unique and not null. Foreign keys maintain referential integrity between tables.',
        ),
      ],
      importantQuestions: [
        Question(
          id: 'db-imp-1',
          prompt: 'Explain different types of keys in relational databases.',
          marks: 10,
        ),
      ],
      pastQuestions: [
        Question(
          id: 'db-past-1',
          prompt: 'What is normalization? Explain 2NF.',
          marks: 5,
        ),
      ],
      quizzes: [
        Quiz(
          id: 'db-quiz-1',
          title: 'SQL Quickfire',
          type: QuizType.mcq,
          difficulty: QuizDifficulty.easy,
          questionCount: 10,
          duration: Duration(minutes: 8),
        ),
      ],
    ),
  ];

  static final List<Chapter> osChapters = [
    Chapter(
      id: 'os-1',
      title: 'Process Scheduling',
      notes: [
        Note(
          id: 'os-note-1',
          title: 'Scheduling Algorithms',
          shortAnswer: 'FCFS, SJF, Priority, Round Robin are core schedulers.',
          detailedAnswer:
              'Schedulers decide CPU allocation. FCFS is simple but can cause convoy. SJF minimizes waiting time. Priority scheduling can starve. Round Robin ensures fairness.',
        ),
      ],
      importantQuestions: [
        Question(
          id: 'os-imp-1',
          prompt: 'Compare FCFS, SJF, and Round Robin scheduling.',
          marks: 10,
        ),
      ],
      pastQuestions: [
        Question(
          id: 'os-past-1',
          prompt: 'What is starvation? How can it be avoided?',
          marks: 5,
        ),
      ],
      quizzes: [
        Quiz(
          id: 'os-quiz-1',
          title: 'Scheduling Levels',
          type: QuizType.level,
          difficulty: QuizDifficulty.medium,
          questionCount: 12,
          duration: Duration(minutes: 10),
        ),
      ],
    ),
  ];

  static final Subject networking = Subject(
    id: 'sub-net',
    name: 'Computer Networking',
    code: 'CS-305',
    accentColor: const Color(0xFF2563EB),
    chapters: networkingChapters,
  );

  static final Subject dbms = Subject(
    id: 'sub-db',
    name: 'Database Management System',
    code: 'CS-306',
    accentColor: const Color(0xFF16A34A),
    chapters: dbmsChapters,
  );

  static final Subject os = Subject(
    id: 'sub-os',
    name: 'Operating Systems',
    code: 'CS-304',
    accentColor: const Color(0xFFF97316),
    chapters: osChapters,
  );

  static final Semester semesterFive = Semester(
    id: 'sem-5',
    name: 'BCA Semester 5',
    subjects: [networking, dbms, os],
  );

  static final Semester semesterFour = Semester(
    id: 'sem-4',
    name: 'BCA Semester 4',
    subjects: [os, dbms],
  );

  static final Semester semesterSix = Semester(
    id: 'sem-6',
    name: 'BCA Semester 6',
    subjects: [networking, dbms],
  );

  static final List<Semester> semesters = [
    semesterFour,
    semesterFive,
    semesterSix,
  ];

  static final UserProfile profile = UserProfile(
    name: 'Suraj Lamichhane',
    email: 'suraj@example.com',
    semester: semesterFive,
    subjects: [networking, dbms, os],
  );

  static final List<WeakTopic> weakTopics = [
    WeakTopic(
      name: 'OSI Layers',
      reason: 'Mixed up layer responsibilities in last quiz.',
    ),
    WeakTopic(
      name: 'TCP vs UDP',
      reason: 'Incorrectly matched protocols to use cases.',
    ),
    WeakTopic(
      name: 'Normalization',
      reason: 'Confused 2NF vs 3NF in timed challenge.',
    ),
  ];

  static final QuizAttempt sampleAttempt = QuizAttempt(
    quiz: networkingChapters.first.quizzes.first,
    score: 4,
    total: 10,
    xpEarned: 120,
    weakTopics: weakTopics,
  );

  static final List<StudyPlanDay> planner = [
    StudyPlanDay(
      label: 'Today',
      tasks: [
        StudyTask(
          title: 'Revise OSI model notes',
          subject: 'Networking',
          isDone: false,
        ),
        StudyTask(
          title: 'Attempt SQL quickfire quiz',
          subject: 'DBMS',
          isDone: true,
        ),
      ],
    ),
    StudyPlanDay(
      label: 'Tomorrow',
      tasks: [
        StudyTask(
          title: 'Solve past questions on scheduling',
          subject: 'Operating Systems',
          isDone: false,
        ),
      ],
    ),
  ];

  static final List<SearchResult> searchResults = [
    SearchResult(
      title: 'OSI Model Layers',
      type: 'Note',
      snippet: '7 layers, responsibilities, quick memory hooks.',
    ),
    SearchResult(
      title: 'TCP vs UDP',
      type: 'Important Question',
      snippet: 'Comparison table, real world examples.',
    ),
    SearchResult(
      title: 'SQL Quickfire',
      type: 'Quiz',
      snippet: '10 MCQs, 8 minutes, medium difficulty.',
    ),
  ];

  static final List<SyllabusItem> syllabus = [
    SyllabusItem(
      subject: 'Computer Networking',
      detail: 'OSI, TCP/IP, routing, congestion control.',
    ),
    SyllabusItem(
      subject: 'Database Management System',
      detail: 'ER model, normalization, SQL, transactions.',
    ),
    SyllabusItem(
      subject: 'Operating Systems',
      detail: 'Process scheduling, memory management, files.',
    ),
  ];
}

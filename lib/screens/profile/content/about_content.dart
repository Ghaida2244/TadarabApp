/// The written copy behind the three "classic" About documents — About Us,
/// Privacy Policy and Terms of Use.
///
/// Started from the Profile design handoff's `DOCS` constant and since
/// revised by the team: the handoff's wording is a draft, not a
/// requirement, so several paragraphs were rewritten to be shorter, to use
/// American spelling, and to describe what the app actually does (for
/// example, Your Rights now points at Edit Profile and an email address,
/// because there is no in-app account deletion).
///
/// Kept as data in one file, as the design does, so the wording can be
/// corrected without touching a screen.
library;

/// One headed block of a document.
class AboutBlock {
  const AboutBlock({required this.heading, required this.body});

  /// The block's heading, e.g. "About Tadarab".
  final String heading;

  /// Its single paragraph.
  final String body;
}

/// A document reachable from the Profile screen's About section.
class AboutDocument {
  const AboutDocument({required this.title, required this.blocks});

  /// The title shown in the navy header.
  final String title;

  /// The blocks, in order.
  final List<AboutBlock> blocks;
}

/// Which document an About row opens.
enum AboutDocumentKind { aboutUs, learningGuide, privacyPolicy, termsOfUse }

/// "About Us".
const kAboutUsDocument = AboutDocument(
  title: 'About Us',
  blocks: [
    AboutBlock(
      heading: 'About Tadarab',
      body:
          'Tadarab is an AI-powered study assistant. Upload your lecture '
          'material, and Tadarab turns it into quizzes and flashcards based '
          'on what you choose to study.',
    ),
    AboutBlock(
      heading: 'How It Helps',
      body:
          'Tadarab builds practice from the mistakes you make, tracks your '
          'progress with points and ranks, and keeps your important dates in '
          "one calendar with reminders, so your studying stays organized.",
    ),
    AboutBlock(
      heading: 'Contact Us',
      body:
          'Questions or feedback? Email us at tadarabapp@gmail.com, and '
          "we'll get back to you.",
    ),
  ],
);

/// "Privacy Policy".
const kPrivacyPolicyDocument = AboutDocument(
  title: 'Privacy Policy',
  blocks: [
    AboutBlock(
      heading: 'Privacy Commitment',
      body:
          'Tadarab respects your privacy and is committed to protecting your '
          'personal information.',
    ),
    AboutBlock(
      heading: 'Data We Collect',
      body:
          'We collect your account details (name and email), the study '
          'materials you upload, the quizzes and flashcards generated from '
          'them, your study progress, and your calendar events. We use this '
          "data only to provide the app's features.",
    ),
    AboutBlock(
      heading: 'AI Processing',
      body:
          'Your uploaded materials are processed by a trusted AI service to '
          'generate quizzes and flashcards.',
    ),
    AboutBlock(
      heading: 'Data Security',
      body:
          'We do not sell your personal information, and we take reasonable '
          'measures to keep your data secure.',
    ),
    AboutBlock(
      heading: 'Your Rights',
      body:
          'You can update your name in Edit Profile. To delete your account, '
          'contact us at tadarabapp@gmail.com.',
    ),
  ],
);

/// "Terms of Use".
const kTermsOfUseDocument = AboutDocument(
  title: 'Terms of Use',
  blocks: [
    AboutBlock(
      heading: 'Using Tadarab',
      body:
          'Tadarab is provided for personal study use. By using the app you '
          'agree to use it lawfully and not to misuse its features.',
    ),
    AboutBlock(
      heading: 'Your Content',
      body:
          'You keep ownership of the materials you upload. You are '
          'responsible for holding the right to upload and study them.',
    ),
    AboutBlock(
      heading: 'Generated Content',
      body:
          'Quizzes and flashcards are generated automatically and may '
          'contain mistakes. Check them against your original material '
          'before relying on them.',
    ),
    AboutBlock(
      heading: 'Account',
      body:
          'Keep your login details private. You are responsible for activity '
          'that happens under your account.',
    ),
    AboutBlock(
      heading: 'Changes',
      body:
          'These terms may be updated as the app develops. Continued use '
          'after an update means you accept the revised terms.',
    ),
  ],
);

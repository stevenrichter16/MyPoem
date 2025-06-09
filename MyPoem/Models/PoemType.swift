import Foundation

/// A size-limited, in-memory list of poem styles.
/// Conforms to Identifiable & Codable so you can still store it on your Request.
struct PoemType: Identifiable, Codable, Hashable {
  let id: String
  let name: String
  let prompt: String
  let maxLength: Int
  let variations: [PoemTypeVariation]
  
  // Get variation by ID, fallback to default variation
  func variation(withId id: String?) -> PoemTypeVariation {
      if let id = id, let variation = variations.first(where: { $0.id == id }) {
          return variation
      }
      return defaultVariation
  }
  
  // Random variation for resending or when user doesn't choose
  var randomVariation: PoemTypeVariation {
      return variations.randomElement() ?? defaultVariation
  }
  
  // Default variation (first one) for initial display
  var defaultVariation: PoemTypeVariation {
      return variations.first ?? PoemTypeVariation(
          id: "default",
          name: "Default",
          summary: "Standard \(name) style",
          prompt: prompt + "{TOPIC}"
      )
  }

  /// Your built-in library
  static let all: [PoemType] = [
    .init(
        id: "haiku",
        name: "Haiku",
        prompt: "Write a haiku about ",
        maxLength: 30,
        variations: [
            PoemTypeVariation(
                id: "traditional",
                name: "Traditional",
                summary: "Classic nature-focused haiku capturing a single moment in time",
                prompt: "Compose a haiku about {TOPIC} that captures a single moment in time. Use concrete sensory details and follow the 5-7-5 syllable pattern. Draw inspiration from the Japanese tradition of observing nature's subtle changes and fleeting beauty. Avoid obvious rhymes or forced metaphors.",
                icon: "leaf"
            ),
            PoemTypeVariation(
                id: "emotional",
                name: "Emotional",
                summary: "Focus on feelings and emotions with quiet revelations",
                prompt: "Write a haiku exploring the feeling or emotion connected to {TOPIC}. Focus on one precise image that embodies this feeling. Use simple, everyday language that creates a quiet revelation. Let the meaning emerge naturally from the juxtaposition of images rather than stating it directly.",
                icon: "heart"
            ),
            PoemTypeVariation(
                id: "seasonal",
                name: "Seasonal",
                summary: "Suggests time of day or season through environmental details",
                prompt: "Create a haiku about {TOPIC} that suggests a specific time of day or season without naming it directly. Use subtle environmental details and natural imagery. The poem should feel like a photograph captured in words, showing rather than telling.",
                icon: "calendar"
            ),
            PoemTypeVariation(
                id: "modern",
                name: "Contemporary",
                summary: "Modern urban life with fresh, unexpected imagery",
                prompt: "Craft a contemporary haiku about {TOPIC} that finds poetry in everyday modern life. Use fresh, unexpected imagery while maintaining the traditional structure. Focus on a moment of surprise or recognition that reveals something deeper about ordinary experience.",
                icon: "building.2"
            ),
            PoemTypeVariation(
                id: "minimalist",
                name: "Minimalist",
                summary: "Spare and essential words with space for imagination",
                prompt: "Write a spare, minimalist haiku about {TOPIC}. Choose words that carry weight and resonance. Each word should be essential. Create space between the images for the reader's imagination to fill. Let silence and implication speak as loudly as the words themselves.",
                icon: "minus.circle"
            )
        ]
    ),
    .init(
        id: "freeverse",
        name: "Free verse",
        prompt: "Write a free verse poem about ",
        maxLength: 100,
        variations: [
            PoemTypeVariation(
                id: "flowing",
                name: "Flowing",
                summary: "Natural thought flow with conversational yet elevated language",
                prompt: "Write a free verse poem about {TOPIC} that follows the natural flow of thought and feeling. Let line breaks create rhythm and breathing space. Use concrete, specific details rather than abstract concepts. Vary your line lengths to create musical phrasing. Avoid forced rhymes—let the language be conversational yet elevated.",
                icon: "wave.3.right"
            ),
            PoemTypeVariation(
                id: "narrative",
                name: "Story-telling",
                summary: "Tells a story or captures a scene with vivid details",
                prompt: "Create a free verse poem that tells a story or captures a scene related to {TOPIC}. Use vivid imagery and sensory details. Let the poem unfold naturally, like someone sharing an important memory. Include specific, unique details that make this experience feel real and personal rather than generic.",
                icon: "book"
            ),
            PoemTypeVariation(
                id: "fragmented",
                name: "Fragmented",
                summary: "Modern style using fragments and white space strategically",
                prompt: "Compose a contemporary free verse poem about {TOPIC} using fragments, short phrases, and white space. Create meaning through juxtaposition and unexpected connections. Use line breaks strategically to control pacing and emphasis. Let the form reflect the content's emotional landscape.",
                icon: "square.split.diagonal"
            ),
            PoemTypeVariation(
                id: "voice-driven",
                name: "Voice-driven",
                summary: "Distinctive personality and conversational tone",
                prompt: "Write a free verse poem about {TOPIC} in a distinctive voice—perhaps conversational, urgent, meditative, or questioning. Let the personality come through in word choice and rhythm. Use enjambment (lines flowing into each other) to create momentum. Make it sound like a real person speaking, not a generic 'poetic' voice.",
                icon: "person.wave.2"
            ),
            PoemTypeVariation(
                id: "image-centered",
                name: "Image-rich",
                summary: "Built through vivid, surprising imagery and fresh metaphors",
                prompt: "Create a free verse poem centered on vivid, surprising imagery related to {TOPIC}. Build the poem through a series of concrete pictures rather than abstract statements. Use metaphors that feel fresh and earned rather than clichéd. Let each image deepen or complicate the previous one.",
                icon: "photo.stack"
            )
        ]
    ),
    .init(
        id: "ode",
        name: "Ode",
        prompt: "Write an ode to ",
        maxLength: 100,
        variations: [
            PoemTypeVariation(
                id: "celebratory",
                name: "Celebratory",
                summary: "Classical praise with elevated language and enthusiasm",
                prompt: "Write an ode celebrating {TOPIC} with genuine enthusiasm and elevated language. Use rich, sensory details and varied stanza lengths. Let your admiration be specific and personal rather than generic praise. Include surprising aspects or angles that reveal why this subject deserves celebration. Avoid flowery clichés—make the language feel both noble and authentic.",
                icon: "party.popper"
            ),
            PoemTypeVariation(
                id: "personal",
                name: "Personal",
                summary: "Intimate connection with gratitude and shared memories",
                prompt: "Compose an ode expressing deep personal connection to {TOPIC}. Write as if speaking to this subject directly. Use intimate, conversational tone mixed with moments of lyrical intensity. Share specific memories or experiences that explain the relationship. Let gratitude and recognition drive the language naturally.",
                icon: "heart.text.square"
            ),
            PoemTypeVariation(
                id: "playful",
                name: "Playful",
                summary: "Contemporary take finding meaning in ordinary things",
                prompt: "Create a contemporary ode to {TOPIC} that finds profound meaning in something ordinary or overlooked. Use humor and wit alongside genuine appreciation. Subvert expectations while maintaining the spirit of celebration. Let the contrast between elevated form and everyday subject create interesting tension.",
                icon: "theatermasks"
            ),
            PoemTypeVariation(
                id: "reflective",
                name: "Reflective",
                summary: "Explores deeper significance and universal questions",
                prompt: "Write an ode that explores the deeper significance of {TOPIC}. Move between concrete description and broader reflection on meaning, mortality, beauty, or human connection. Use the celebration as a way to examine larger questions about life and experience. Balance the personal with the universal.",
                icon: "brain.head.profile"
            ),
            PoemTypeVariation(
                id: "sensory",
                name: "Sensory",
                summary: "Immersive experience through rich textures and details",
                prompt: "Craft an ode that immerses the reader in the sensory experience of {TOPIC}. Use synesthesia (mixing senses), rich textures, sounds, tastes, and visual details. Make the subject come alive through physical description. Let the accumulation of sensory details create the feeling of celebration and wonder.",
                icon: "eye"
            )
        ]
    ),
    .init(
        id: "limerick",
        name: "Limerick",
        prompt: "Write a limerick about ",
        maxLength: 80,
        variations: [
            PoemTypeVariation(
                id: "wordplay",
                name: "Wordplay",
                summary: "Clever puns and unexpected rhymes with musical rhythm",
                prompt: "Write a clever limerick about {TOPIC} with an AABBA rhyme scheme. Use wordplay, puns, or unexpected rhymes. Keep it lighthearted and fun. The humor should come from clever language rather than obvious jokes. Make the rhythm bounce along naturally—limericks should be musical and easy to say aloud.",
                icon: "textformat.abc"
            ),
            PoemTypeVariation(
                id: "character",
                name: "Character",
                summary: "Brief story about someone with vivid personality",
                prompt: "Create a limerick that tells a brief story about someone encountering {TOPIC}. Introduce a character in the first line, develop a situation in lines 2-4, and provide a humorous conclusion in line 5. Use vivid, specific details rather than generic descriptions. Let the character's personality come through in the language.",
                icon: "person.fill.questionmark"
            ),
            PoemTypeVariation(
                id: "absurd",
                name: "Absurd",
                summary: "Delightfully nonsensical with surreal imagery",
                prompt: "Compose a delightfully absurd limerick featuring {TOPIC}. Embrace nonsense and unexpected combinations. Use surreal imagery and impossible situations. The humor should come from the delightful illogic and surprising word combinations. Keep the tone light and whimsical rather than forced.",
                icon: "rainbow"
            ),
            PoemTypeVariation(
                id: "observational",
                name: "Observational",
                summary: "Gentle humor about everyday life experiences",
                prompt: "Write a limerick that makes a gentle, humorous observation about {TOPIC} in daily life. Use wit rather than meanness. Find the funny side of common experiences. The humor should be relatable and good-natured. Include specific, recognizable details that make people smile in recognition.",
                icon: "magnifyingglass"
            ),
            PoemTypeVariation(
                id: "rhythmic",
                name: "Musical",
                summary: "Emphasizes sound patterns and bouncy meter",
                prompt: "Create a limerick about {TOPIC} that emphasizes musical rhythm and sound patterns. Use alliteration, internal rhymes, and bouncy meter. Make it fun to read aloud. The pleasure should come as much from how it sounds as what it says. Play with the sounds of language while maintaining coherent meaning.",
                icon: "music.note"
            )
        ]
    ),
    .init(
        id: "ballad",
        name: "Ballad",
        prompt: "Write a ballad about ",
        maxLength: 100,
        variations: [
            PoemTypeVariation(
                id: "traditional",
                name: "Traditional",
                summary: "Classic storytelling with strong narrative arc",
                prompt: "Write a ballad that tells a story about {TOPIC} in simple, clear language with a strong narrative arc. Use quatrains (4-line stanzas) with an ABAB or ABCB rhyme scheme. Include dialogue or dramatic moments. Focus on action and emotion rather than description. Let the story unfold naturally, like a song someone would remember and retell.",
                icon: "scroll"
            ),
            PoemTypeVariation(
                id: "folk",
                name: "Folk Song",
                summary: "Traditional folk style with refrains and universal themes",
                prompt: "Compose a ballad about {TOPIC} in the style of a traditional folk song. Use repetition, refrains, and simple but evocative language. Include universal themes like love, loss, struggle, or triumph. Make it feel like it could be passed down through generations. Use everyday language that carries emotional weight.",
                icon: "guitars"
            ),
            PoemTypeVariation(
                id: "contemporary",
                name: "Contemporary",
                summary: "Modern story with current language and timeless appeal",
                prompt: "Create a modern ballad about {TOPIC} that tells a contemporary story with timeless appeal. Use current language and references while maintaining the ballad's storytelling tradition. Include specific details that ground the story in real experience. Let the rhythm carry the narrative forward naturally.",
                icon: "newspaper"
            ),
            PoemTypeVariation(
                id: "character-driven",
                name: "Character-driven",
                summary: "Focuses on specific character's experience and growth",
                prompt: "Write a ballad that focuses on a specific character's experience with {TOPIC}. Let their voice and personality come through clearly. Include their background, motivations, and how this experience changes them. Use dialogue and internal thoughts. Make the character feel real and complex, not just a vehicle for the story.",
                icon: "person.crop.square"
            ),
            PoemTypeVariation(
                id: "atmospheric",
                name: "Atmospheric",
                summary: "Emphasizes mood and setting as much as story",
                prompt: "Craft a ballad about {TOPIC} that emphasizes mood and atmosphere as much as story. Use detailed descriptions of setting, weather, and environment to create emotional resonance. Let the external world reflect the internal drama. Build tension through accumulating details rather than dramatic action alone.",
                icon: "cloud.fog"
            )
        ]
    ),
    .init(
        id: "sonnet",
        name: "Sonnet",
        prompt: "Write a sonnet about ",
        maxLength: 140,
        variations: [
            PoemTypeVariation(
                id: "shakespearean",
                name: "Shakespearean",
                summary: "Traditional ABAB CDCD EFEF GG with twist in final couplet",
                prompt: "Write a Shakespearean sonnet (14 lines, ABAB CDCD EFEF GG) exploring {TOPIC}. Develop an argument or meditation through three quatrains, then provide a twist, resolution, or surprise in the final couplet. Use iambic pentameter naturally—don't force the rhythm. Let the form serve the content, building to a satisfying conclusion.",
                icon: "book.closed"
            ),
            PoemTypeVariation(
                id: "petrarchan",
                name: "Petrarchan",
                summary: "Octave presents problem, sestet offers resolution",
                prompt: "Compose a Petrarchan sonnet about {TOPIC} with an octave (8 lines) presenting a problem or question, and a sestet (6 lines) offering resolution or response. Use the 'volta' (turn) at line 9 to shift perspective or introduce new insight. Let the tight form concentrate the emotional intensity.",
                icon: "arrow.turn.down.right"
            ),
            PoemTypeVariation(
                id: "modern",
                name: "Contemporary",
                summary: "Modern language within traditional 14-line structure",
                prompt: "Create a contemporary sonnet about {TOPIC} that uses modern language while respecting the form's essential structure. You may take liberties with strict meter while maintaining the 14-line framework and strong concluding element. Let current speech patterns create a natural rhythm within the formal constraints.",
                icon: "sparkles"
            ),
            PoemTypeVariation(
                id: "philosophical",
                name: "Philosophical",
                summary: "Moves from specific to universal, exploring larger questions",
                prompt: "Write a sonnet that uses {TOPIC} as a starting point for deeper philosophical reflection. Move from the specific to the universal, using the subject to explore larger questions about existence, beauty, time, or human nature. Let the formal structure support the logical development of ideas.",
                icon: "brain.head.profile"
            ),
            PoemTypeVariation(
                id: "emotional",
                name: "Emotional",
                summary: "Captures intense emotion with concentrated language",
                prompt: "Craft a sonnet that captures intense emotion related to {TOPIC}. Use the form's compression to distill feeling into concentrated language. Build emotional pressure through the quatrains and release it in the concluding lines. Let passion and precision work together to create a powerful effect.",
                icon: "heart.fill"
            )
        ]
    ),
  ]
}

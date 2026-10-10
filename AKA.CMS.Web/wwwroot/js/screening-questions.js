/* Shared screening question bank — used by screening.js and add-case.js */
window.CMS_SCREEN_QUESTIONS = (function () {
  var A_PG = [ // PHQ-9 / GAD-7 anchors (0-3)
    { t: 'Not at all', v: 0 },
    { t: 'Several days', v: 1 },
    { t: 'More than half the days', v: 2 },
    { t: 'Nearly every day', v: 3 }
  ];
  var A_DASS = [ // DASS-21 anchors (0-3)
    { t: 'Did not apply to me at all', v: 0 },
    { t: 'Applied to me to some degree, or some of the time', v: 1 },
    { t: 'Applied to me to a considerable degree, or a good part of time', v: 2 },
    { t: 'Applied to me very much, or most of the time', v: 3 }
  ];
  var A_YN = [{ t: 'No', v: 0 }, { t: 'Yes', v: 1 }];

  function std(text, anchors) { return { text: text, options: anchors || A_PG }; }

  var QUESTIONS = {
    PHQ9: [
      std('Little interest or pleasure in doing things'),
      std('Feeling down, depressed, or hopeless'),
      std('Trouble falling or staying asleep, or sleeping too much'),
      std('Feeling tired or having little energy'),
      std('Poor appetite or overeating'),
      std('Feeling bad about yourself — or that you are a failure or have let yourself or your family down'),
      std('Trouble concentrating on things, such as reading the newspaper or watching television'),
      std('Moving or speaking so slowly that other people could have noticed — or the opposite, being so fidgety or restless that you have been moving around a lot more than usual'),
      std('Thoughts that you would be better off dead, or of hurting yourself in some way')
    ],
    GAD7: [
      std('Feeling nervous, anxious, or on edge'),
      std('Not being able to stop or control worrying'),
      std('Worrying too much about different things'),
      std('Trouble relaxing'),
      std('Being so restless that it is hard to sit still'),
      std('Becoming easily annoyed or irritable'),
      std('Feeling afraid as if something awful might happen')
    ],
    DASS21: [
      std('I found it hard to wind down', A_DASS),
      std('I was aware of dryness of my mouth', A_DASS),
      std("I couldn't seem to experience any positive feeling at all", A_DASS),
      std('I experienced breathing difficulty (e.g. excessively rapid breathing, breathlessness in the absence of physical exertion)', A_DASS),
      std('I found it difficult to work up the initiative to do things', A_DASS),
      std('I tended to over-react to situations', A_DASS),
      std('I experienced trembling (e.g. in the hands)', A_DASS),
      std('I felt that I was using a lot of nervous energy', A_DASS),
      std('I was worried about situations in which I might panic and make a fool of myself', A_DASS),
      std('I felt that I had nothing to look forward to', A_DASS),
      std('I found myself getting agitated', A_DASS),
      std('I found it difficult to relax', A_DASS),
      std('I felt down-hearted and blue', A_DASS),
      std('I was intolerant of anything that kept me from getting on with what I was doing', A_DASS),
      std('I felt I was close to panic', A_DASS),
      std('I was unable to become enthusiastic about anything', A_DASS),
      std("I felt I wasn't worth much as a person", A_DASS),
      std('I felt that I was rather touchy', A_DASS),
      std('I was aware of the action of my heart in the absence of physical exertion (e.g. sense of heart rate increase, heart missing a beat)', A_DASS),
      std('I felt scared without any good reason', A_DASS),
      std('I felt that life was meaningless', A_DASS)
    ],
    SBQR: [
      { text: 'Have you ever thought about or attempted to kill yourself?', options: [
        { t: 'Never', v: 1 },
        { t: 'It was just a brief passing thought', v: 2 },
        { t: 'I have had a plan at least once to kill myself but did not try to do it or work it out', v: 3 },
        { t: 'I have attempted to kill myself, but did not want to die', v: 4 },
        { t: 'I have attempted to kill myself, and really hoped to die', v: 4 }
      ]},
      { text: 'How often have you thought about killing yourself in the past year?', options: [
        { t: 'Never', v: 1 },
        { t: 'Rarely (1 time)', v: 2 },
        { t: 'Sometimes (2 times)', v: 3 },
        { t: 'Often (3–4 times)', v: 4 },
        { t: 'Very often (5 or more times)', v: 5 }
      ]},
      { text: 'Have you ever told someone that you were going to commit suicide, or that you might do it?', options: [
        { t: 'No', v: 1 },
        { t: 'Yes, at one time, but did not really want to die', v: 2 },
        { t: 'Yes, at one time, and really wanted to die', v: 3 },
        { t: 'Yes, more than once, and really wanted to do it', v: 3 }
      ]},
      // Published SBQ-R item 4 range is 0–6 (matches server validation).
      { text: 'How likely is it that you will attempt suicide someday?', options: [
        { t: 'Never', v: 0 },
        { t: 'No chance at all', v: 1 },
        { t: 'Rather unlikely', v: 2 },
        { t: 'Unlikely', v: 3 },
        { t: 'Likely', v: 4 },
        { t: 'Rather likely', v: 5 },
        { t: 'Very likely', v: 6 }
      ]}
    ],
    CSSRS: [
      std('Have you wished you were dead or wished you could go to sleep and not wake up?', A_YN),
      std('Have you actually had any thoughts of killing yourself?', A_YN),
      std('Have you been thinking about how you might do this?', A_YN),
      std('Have you had these thoughts and had some intention of acting on them?', A_YN),
      std('Have you started to work out or worked out the details of how to kill yourself? Do you intend to carry out this plan?', A_YN),
      std('Have you done anything, started to do anything, or prepared to do anything to end your life?', A_YN)
    ]
  };
  return QUESTIONS;
})();

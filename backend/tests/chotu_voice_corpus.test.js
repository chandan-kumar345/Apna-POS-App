const corpus = require('./fixtures/chotu_voice_commands.json');
const { normalizeSpokenText } = require('../src/services/chotu/speechProvider');

describe(`Chotu voice corpus v${corpus.version}`, () => {
  it.each(corpus.examples)('$heard', ({ heard, normalized }) => {
    expect(normalizeSpokenText(heard).toLowerCase()).toBe(normalized);
  });
});

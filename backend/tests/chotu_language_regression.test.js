const Engine = require('../src/services/chotu/aiCommandEngine');
const Matcher = require('../src/services/chotu/productMatcher');
const menu = [
  { _id: 'naan', name: 'Butter Naan', aliases: ['butter nan'] },
  { _id: 'paneer', name: 'पनीर टिक्का' },
];

describe('Chotu typed and spoken menu grounding', () => {
  test.each([
    'Can you add two butter naan to table number five',
    'Please add 2 butter naan for table no. 5',
    'Table 5 pe do butter nan laga do',
  ])('%s', (text) => {
    const command = Engine.parseCommand({ text, availableProducts: menu });
    expect(command.table_number).toBe('5');
    expect(command.items).toHaveLength(1);
    expect(command.items[0]).toMatchObject({ product_id: 'naan', quantity: 2, matched: true });
  });
  test('matches Hindi catalog names instead of discarding their characters', () => {
    const command = Engine.parseCommand({ text: 'टेबल 5 पर एक पनीर टिक्का लगा दो', availableProducts: menu });
    expect(command.items[0]).toMatchObject({ product_id: 'paneer', quantity: 1, matched: true });
  });
  test('splits plus and ampersand without losing item quantities', () => {
    const command = Engine.parseCommand({ text: 'Table 5 pe 2 butter naan + 1 paneer tikka', availableProducts: [{ _id: 'n', name: 'Butter Naan' }, { _id: 'p', name: 'Paneer Tikka' }] });
    expect(command.items.map((i) => i.quantity)).toEqual([2, 1]);
    expect(command.items.every((i) => i.matched)).toBe(true);
  });
  test('does not use a partial word as an exact substring match', () => {
    expect(Matcher.matchProduct('tea', [{ name: 'Steak', _id: 's' }]).match).toBeNull();
    expect(Matcher.matchProduct('unicorn soup', menu).match).toBeNull();
  });
  test('asks when multiple menu variants match', () => {
    expect(Matcher.matchProduct('cola', [{ name: 'Cola 300ml' }, { name: 'Cola 750ml' }]).tier).toBe('ambiguous');
  });
  test('does not confuse a spoken table number with the requested quantity', () => {
    const update = Engine.parseCommand({ text: 'Table 5 butter naan ko 4 kar do', availableProducts: menu });
    expect(update.quantity).toBe(4);
    expect(update.table_number).toBe('5');
    const remove = Engine.parseCommand({ text: 'Remove 2 butter naan from table 5', availableProducts: menu });
    expect(remove.quantity).toBe(2);
  });
  test.each([['Change table to 6', 'SWITCH_TABLE', '6'], ['K O T bhejo', 'SEND_KOT', null], ['Bill banao', 'GENERATE_BILL', null]])('%s', (text, intent, table) => {
    const command = Engine.parseCommand({ text, availableProducts: menu });
    expect(command.intent).toBe(intent);
    expect(command.table_number).toBe(table);
  });
});

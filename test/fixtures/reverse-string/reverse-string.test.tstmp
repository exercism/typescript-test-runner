import { reverse } from './reverse-string'

describe('Reverse String', () => {
  it.task(1,'an empty string', () => {
    const expected = ''
    expect(reverse('')).toEqual(expected)
  })

  it.task(2, 'a word', () => {
    const expected = 'tobor'
    expect(reverse('robot')).toEqual(expected)
  })

  it.task(3, 'a capitalized word', () => {
    const expected = 'nemaR'
    expect(reverse('Ramen')).toEqual(expected)
  })

  it.task(4, 'a sentence with punctuation', () => {
    const expected = `!yrgnuh m'I`
    expect(reverse(`I'm hungry!`)).toEqual(expected)
  })

  it.task(5, 'a palindrome', () => {
    const expected = 'racecar'
    expect(reverse('racecar')).toEqual(expected)
  })
})

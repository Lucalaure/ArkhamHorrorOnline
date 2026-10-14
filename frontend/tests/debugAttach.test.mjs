import assert from 'node:assert/strict'
import test from 'node:test'
import { fileURLToPath, URL } from 'node:url'

import { createServer } from 'vite'

/* The debug attach builds `DebugAttachCard` by hand, and reads where a card sits
off its placement, so both are pinned here against the backend's shapes. */
async function load(t) {
  const server = await createServer({
    root: fileURLToPath(new URL('..', import.meta.url)),
    appType: 'custom',
    logLevel: 'silent',
    server: { middlewareMode: true, hmr: false },
  })
  t.after(() => server.close())
  return server.ssrLoadModule('/src/arkham/debugAttach.ts')
}

test('attach encodes DebugAttachCard and discard the ordinary Discard', async (t) => {
  const { attachMessage, discardMessage } = await load(t)
  const card = { tag: 'AssetTarget', contents: 'a1' }
  const host = { tag: 'ActTarget', contents: '01108' }
  assert.deepEqual(attachMessage(card, host), { tag: 'DebugAttachCard', contents: [card, host] })
  assert.deepEqual(discardMessage(card), { tag: 'Discard', contents: [null, { tag: 'GameSource' }, card] })
})

test('a placement names the card it is attached to', async (t) => {
  const { placementHost } = await load(t)
  assert.deepEqual(placementHost({ tag: 'AttachedToAsset', contents: ['a2', null] }), { tag: 'AssetTarget', contents: 'a2' })
  assert.deepEqual(placementHost({ tag: 'AttachedToEnemy', contents: 'e1' }), { tag: 'EnemyTarget', contents: 'e1' })
  assert.deepEqual(placementHost({ tag: 'AttachedToInvestigator', contents: '01001' }), { tag: 'InvestigatorTarget', contents: '01001' })
  assert.equal(placementHost({ tag: 'InPlayArea', contents: '01001' }), null)
  assert.equal(placementHost(undefined), null)
})

test('attachedTo finds every kind riding on a host', async (t) => {
  const { attachedTo } = await load(t)
  const on = (contents) => ({ tag: 'AttachedToTreachery', contents })
  const game = {
    assets: { a1: { id: 'a1', placement: on('t1') }, a2: { id: 'a2', placement: { tag: 'InPlayArea', contents: 'i' } } },
    events: { e1: { id: 'e1', placement: on('t1') } },
    skills: { s1: { id: 's1', placement: on('t1') }, s2: { id: 's2' } },
    treacheries: { t1: { id: 't1', placement: { tag: 'AtLocation', contents: 'l' } }, t2: { id: 't2', placement: on('t9') } },
  }
  assert.deepEqual(attachedTo(game, { tag: 'TreacheryTarget', contents: 't1' }), {
    assets: ['a1'],
    events: ['e1'],
    skills: ['s1'],
    treacheries: [],
  })
})

test('stackedOn follows enemies, so The Beyond cannot ride its own spirit', async (t) => {
  const { stackedOn } = await load(t)
  const game = {
    assets: {
      beyond: { id: 'beyond', placement: { tag: 'InPlayArea', contents: 'i' } },
      lamp: { id: 'lamp', placement: { tag: 'AttachedToEnemy', contents: 'spirit' } },
    },
    events: {},
    skills: {},
    treacheries: {},
    enemies: {
      spirit: { id: 'spirit', placement: { tag: 'AttachedToAsset', contents: ['beyond', null] } },
      other: { id: 'other', placement: { tag: 'AtLocation', contents: 'l' } },
    },
  }
  assert.deepEqual(
    [...stackedOn(game, { tag: 'AssetTarget', contents: 'beyond' })].sort(),
    ['AssetTarget:beyond', 'AssetTarget:lamp', 'EnemyTarget:spirit'],
  )
})

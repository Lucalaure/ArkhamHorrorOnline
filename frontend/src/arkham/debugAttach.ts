/* Debug-only attaching: the frontend half of the backend `DebugAttachCard`.
 *
 * A card that can move (an asset, event, skill or treachery in play) is attached
 * to any other card on the table. Hosts are every kind the engine has an
 * `AttachedTo...` placement for. Taking it off again is a discard: there is no
 * "detached" place every card has (an encounter treachery or a story asset has no
 * one to hand it back to), but every card has a discard pile.
 */
import type { Game } from '@/arkham/types/Game'
import type { Placement } from '@/arkham/types/Placement'

export type AttachableKind = 'AssetTarget' | 'EventTarget' | 'SkillTarget' | 'TreacheryTarget'

export type HostKind =
  | 'InvestigatorTarget'
  | 'LocationTarget'
  | 'EnemyTarget'
  | 'AssetTarget'
  | 'EventTarget'
  | 'TreacheryTarget'
  | 'ActTarget'
  | 'AgendaTarget'

export type AttachableTarget = { tag: AttachableKind, contents: string }
export type HostTarget = { tag: HostKind, contents: string }

export function attachMessage(card: AttachableTarget, host: HostTarget) {
  return { tag: 'DebugAttachCard', contents: [card, host] }
}

/* The ordinary discard, so the card goes to its owner's pile (or the encounter
 * discard) and the leave-play windows fire as they would at the table. */
export function discardMessage(card: AttachableTarget) {
  return { tag: 'Discard', contents: [null, { tag: 'GameSource' }, card] }
}

/* The card a placement attaches to, or null when it is not attached. */
export function placementHost(placement: Placement | undefined): HostTarget | null {
  switch (placement?.tag) {
    case 'AttachedToLocation': return { tag: 'LocationTarget', contents: placement.contents }
    case 'AttachedToEnemy': return { tag: 'EnemyTarget', contents: placement.contents }
    case 'AttachedToAsset': return { tag: 'AssetTarget', contents: placement.contents[0] }
    case 'AttachedToEvent': return { tag: 'EventTarget', contents: placement.contents }
    case 'AttachedToTreachery': return { tag: 'TreacheryTarget', contents: placement.contents }
    case 'AttachedToAct': return { tag: 'ActTarget', contents: placement.contents }
    case 'AttachedToAgenda': return { tag: 'AgendaTarget', contents: placement.contents }
    case 'AttachedToInvestigator': return { tag: 'InvestigatorTarget', contents: placement.contents }
    default: return null
  }
}

export const sameTarget = (a: { tag: string, contents: string }, b: { tag: string, contents: string }) =>
  a.tag === b.tag && a.contents === b.contents

export type AttachedCards = {
  assets: string[]
  events: string[]
  skills: string[]
  treacheries: string[]
}

const targetKey = (t: { tag: string, contents: string }) => `${t.tag}:${t.contents}`

/* `card` and every card riding on it, however deep, as `Tag:id` keys. Attaching
 * `card` to any of these would make two cards hold each other and draw each other
 * forever. Enemies count: The Beyond holds spirits, and an enemy holds assets. */
export function stackedOn(game: Game, card: { tag: string, contents: string }): Set<string> {
  const seen = new Set<string>([targetKey(card)])
  const queue: HostTarget[] = [card as HostTarget]
  while (queue.length > 0) {
    const host = queue.pop()!
    const on = attachedTo(game, host)
    const riders: HostTarget[] = [
      ...on.assets.map((id) => ({ tag: 'AssetTarget' as const, contents: id })),
      ...on.events.map((id) => ({ tag: 'EventTarget' as const, contents: id })),
      ...on.treacheries.map((id) => ({ tag: 'TreacheryTarget' as const, contents: id })),
      ...Object.values(game.enemies)
        .filter((e) => { const h = placementHost(e.placement); return h !== null && sameTarget(h, host) })
        .map((e) => ({ tag: 'EnemyTarget' as const, contents: e.id })),
    ]
    for (const rider of riders) {
      if (seen.has(targetKey(rider))) continue
      seen.add(targetKey(rider))
      queue.push(rider)
    }
  }
  return seen
}

/* Everything attached to `host`, read off each card's own placement. */
export function attachedTo(game: Game, host: HostTarget): AttachedCards {
  const on = (placement: Placement | undefined) => {
    const h = placementHost(placement)
    return h !== null && sameTarget(h, host)
  }
  return {
    assets: Object.values(game.assets).filter((a) => on(a.placement)).map((a) => a.id),
    events: Object.values(game.events).filter((e) => on(e.placement)).map((e) => e.id),
    skills: Object.values(game.skills).filter((s) => on(s.placement)).map((s) => s.id),
    treacheries: Object.values(game.treacheries).filter((t) => on(t.placement)).map((t) => t.id),
  }
}

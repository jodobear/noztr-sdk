# Mixed DM Outbound Naming Migration

Pre-`1.0` mixed-DM outbound type cleanup:

- `MixedDmOutboundStorage` -> `OutboundStorage`
- `MixedDmDirectMessageRequest` -> `OutboundRequest`
- `MixedDmRememberedDirectMessageRequest` -> `RememberedOutboundRequest`
- `MixedDmPreparedMailboxDirectMessage` -> `PreparedMailboxOutbound`
- `MixedDmPreparedLegacyDirectMessage` -> `PreparedLegacyOutbound`
- `MixedDmPreparedDirectMessage` -> `PreparedOutbound`
- `MixedDmRememberedPreparedDirectMessage` -> `RememberedPreparedOutbound`

Scope:
- only the grouped `noztr_sdk.client.dm.mixed.*` route changed
- the mixed DM client itself stayed at `noztr_sdk.client.dm.mixed.MixedDmClient`

Reason:
- the grouped namespace already carries the `dm.mixed` context
- the older names repeated too much of that path and made the outbound route harder to read and use

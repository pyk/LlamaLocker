# Llama Locker v0

Overview:

- `LlamaLocker` have one `Owner`
- `LlamaLocker` distribute the rewards on Weekly epochs
- `LlamaLocker` weekly epochs begin at Thursday 0:00 UTC

Owner:

- `Owner` can add new reward token via `addRewardToken(address)`
- `Owner` can topup weekly rewards via `addReward(tokenAddress, amount)` (vlCVX
  styles)

User:

- User can lock their llamas via `lock(tokenIds)`
- llamas will be locked for 4 weeks (plus X number of days until the next
  Thursday)
- User will be eligible to claim share of the rewards on the next epoch
- User can unlock their llamas via `unlock(tokenIds)`

## Getting started

Make sure to use latest version of foundry:

```shell
foundryup
```

Install dependencies:

```shell
forge install
```

Run the tests:

```shell
forge test
```

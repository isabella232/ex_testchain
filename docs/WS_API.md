## WS API

**DEPRECATED**
**API moved into https://github.com/makerdao/staxx**

ExTestchain will use special port `4000` for internal communication.
This port is exposed by default and you don't need to add `--expose 4000` to `docker run` command.

WS API is based on [Phoenix Channels](https://hexdocs.pm/phoenix/channels.html#content)

And main idea is to spawn new channel for every chain.

For example: If you start new chain with id `15733048862987664459` system will pose all notifications and receive commands for this chain in `chain:15733048862987664459` channel.

So you have to join new channel after starting chain.

```javascript
const options = {
    type: chain, // For now "geth" or "ganache". (If omited - "ganache" will be used)
    accounts: 2, // Number of account to be created on chain start (1 - if ommited)
    block_mine_time: 0, // how often new block should be mined (0 - instamine)
    clean_on_stop: true, // Will delete chain db folder after chain stop
}
api.push("start", options)
    .receive("ok", ({id: id}) => {
        console.log('Created new chain', id)
        start_channel(id)
    })
    .receive('error', console.error)
    .receive('timeout', () => console.log('Network issues'))
```

### Examples

Some examples you might be find in [index.html](../apps/web_api/priv/static/index.html)

## API description

All description is based on [Phoenix.Message](https://hexdocs.pm/phoenix/channels.html#messages) scructure

### List of all chains
```js
{
    topic: 'api',
    event: 'list_chains',
    payload: {}
}
```

And in response you will get list of available snapshots with details

```js
api_channel
    .push('list_chains')
    .receive('ok', ({ chains: chains }) => console.log('Chains list', chains))
    .receive('error', console.error)
```

### Starting new chain

```js
{
    topic: 'api',
    event: 'start',
    payload: {
        type: "geth", // For now "geth" or "ganache". (If omited - "ganache" will be used)
        accounts: 2, // Number of account to be created on chain start (optional, default is 1)
        block_mine_time: 0, // how often new block should be mined (0 - instamine)
        clean_on_stop: true, // Will delete chain db folder after chain stop
        snapshot_id: "some_snapshot_id", // Will start chain based on snapshot_id (No new accounts will be created)
    }
}
```

As response you will get chain id that initializing.
Example: `{id: "15733048862987664459"}`

**Note**
Returned ID does not mean that chain started successfully.
You have to wait for event from chain channel. See [Events](#events)

### Start exising chain from storage

```js
{
    topic: 'api',
    event: 'start_existing',
    payload: {
      id: '15733048862987664459'
    }
}
```

As response you will get chain id that initializing.
Example: `{id: "15733048862987664459"}`

**Note**
Returned ID does not mean that chain started successfully.
You have to wait for event from chain channel. See [Events](#events)

### Stoping chain

```js
{
    topic: `chain:${chain_id}`,
    event: 'stop',
    payload: {}
}
```

Success response will mean chain stopped.
Example:
```js
chain_channel
    .push('stop')
    .receive('ok', () => console.log('Chain stooped'))
    .receive('error', console.error)
```

### Making snapshot

```js
{
    topic: `chain:${chain_id}`,
    event: 'take_snapshot',
    payload: {
        description: "" // If description is not empty string - snapshot will be stored in DB
    }
}
```

And will get response with no values.
You have to handle `snapshot_taken` event with all details from snapshot

Example of action:
```js
chain_channel
    .push('take_snapshot')
    .receive('ok', () => console.log('Snapshot for chain %s processing', id))
    .receive('error', console.error)
```

### Reverting snapshot

```js
{
    topic: `chain:${chain_id}`,
    event: 'revert_snapshot',
    payload: {
        snapshot: 'some-snapshot-id' // normaly it will be something like: '3680968141515592180'
    }
}
```

And empty response will mean everything - good.
You will have to wait `snapshot_reverted` event

Example of action:
```js
chain_channel
    .push('revert_snapshot', { snapshot: snapshot_id_we_got })
    .receive('ok', () => console.log('Snapshot restored for chain %s', id))
    .receive('error', console.error)
```

### Removing chain
```js
{
    topic: `api`,
    event: 'remove_chain',
    payload: {
        id: 'some-chain-id' // normaly it will be something like: '3680968141515592180'
    }
}
```

Example of action:
```js
api_channel
    .push('remove_chain', { id: chain_id })
    .receive('ok', () => console.log('Chain removed %s', id))
    .receive('error', console.error)
```

Another option for removing chain is HTTP endpoint:
`DELETE http://localhost:4000/chain/{chain_id}`


### Chain details
To load chain details you could use GET HTTP endpoint `/chain/chain_id`

Example:
`http://localhost:4000/chain/3922963434540054103`

Response:
```json
{  
   "details":{  
      "accounts":[  
         {  
            "address":"0x222aded03619a967a36619360f79c577e3f3c64e",
            "balance":100000000000000000000,
            "priv_key":"bfe8f5d1d5af65ab051a0fb7a585514b07fe1e736a7d779741c3ccddf89e4dbb"
         },
         {  
            "address":"0x7a88a88a6ab02bd97c17afccdfd71f73050ef69a",
            "balance":100000000000000000000,
            "priv_key":"ff512ca92e7d4afdb8372e77ffb153106c71bd519156437aed845e09c039c894"
         }
      ],
      "coinbase":"0x222aded03619a967a36619360f79c577e3f3c64e",
      "id":"3922963434540054103",
      "rpc_url":"http://localhost:8597",
      "ws_url":"ws://localhost:8560"
   },
   "status":0
}
```

**Note**: balance is not actual balance. It's initial balance for account.

## Events
Because some operations might take some time or for example errors might appear randomly
ex_testchain provides you with set of events for handling such situations.

Event are firing only for chains. So you have to listen chain channel `chain:{id_here}`.

Using `phoenix.js` you could add listener for special event.
Example:
```js
const channel = socket.channel(`chain:${chain_id}`)
channel
    .join()
    .receive("ok", () => console.log(`Joined to chain:${chain_id} channel`))
    .receive("error", ({reason}) => console.log("failed join", reason) )
    .receive("timeout", () => console.log("Networking issue. Still waiting..."))

// registering event listeners
channel.on('started', (data) => console.log('Chain started', data))
channel.on('error', (err) => console.error('Chain received error', err))
channel.on('stopped', (data) => console.log('Chain stopped', data))
channel.on('snapshot_taken', (data) => console.log('Snapshot taked', snapsht_data))
channel.on('snapshot_reverted', (data) => console.log('Snapshot reverted', data))
```

**Note**:
After some actions like `take_snapshot` and `revert_snapshot` chain will be restarted
And you will receive `started` event again when chain will become operational

List of available events:
 - `started`
 - `stopped`
 - `error`
 - `snapshot_taken`
 - `snapshot_reverted`

### Error
Error event might be fired at any time.
Event: `error`
Event will be fired to `api` and `chain:${id}` channels

Payload example:
```js
{
    "message": "some error"
}
```

### Chain started
Event: `started`
Event will be fired to `api` channel and `chain:${id}` as well.

Payload Example:
```js
{
    "accounts": [
        "0x583a5656a78d3136d213505a704becba3e2bf548","0x316cc3522de00d9e276adc457d53e31eaa25c921"
    ],
    "coinbase": "0x583a5656a78d3136d213505a704becba3e2bf548",
    "id": "15685858230525373105",
    "rpc_url": "http://localhost:8545",
    "ws_url": "ws://localhost:8546"
}
```

### Snapshot taked
Event: `snapshot_taken`
Event will be fired to `chain:${id}` channel.
`path_to` in Payload is a snapshot id that you will use for restoring snapshot

Payload example:
```js
{
    chain: "geth",
    date: "2019-01-12T16:25:29.278712Z",
    description: "test",
    id: "3680968141515592180",
    path: "/tmp/snapshots/3680968141515592180.tgz"
}
```

### Snapshot reverted
Event: `snapshot_reverted`
Event will be fired to `chain:${id}` channel

Payload example:
```js
{
    chain: "geth",
    date: "2019-01-12T16:25:29.278712Z",
    description: "test",
    id: "3680968141515592180",
    path: "/tmp/snapshots/3680968141515592180.tgz"
}
```

### Stopped
Event `stopped`
Event will be fired to `chain:${id}` channel
Payload will be empty

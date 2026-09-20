<div align="center">
    <img src="./assets/logo.svg" alt="" width="192" align="center" />
    <h1 align="center">Welcome to Forgejo</h1>
</div>

Hi there! Tired of big platforms playing monopoly?
Providing Git hosting for your project, friends, company or community?
**Forgejo** (/for'd&#865;ʒe.jo/ inspired by forĝejo – the Esperanto word for *forge*) has you covered with its intuitive interface,
light and easy hosting and a lot of built-in functionality.

Forgejo was [created in 2022](https://forgejo.org/2022-12-15-hello-forgejo/)
because we think that the project should be owned by an independent community.
If you second that, then Forgejo is for you!
Our promise: **Independent Free/Libre Software forever!**

## What does Forgejo offer?

If you like any of the following, Forgejo is literally meant for you:

- Lightweight: Forgejo can easily be hosted on nearly **every machine**.
  Running on a Raspberry? Small cloud instance? No problem!
- Project management: Besides Git hosting, Forgejo offers issues,
  pull requests, wikis, kanban boards and much more to **coordinate with your team**.
- Publishing: Have something to share? Use **releases** to host your software for download,
  or use the **package registry** to publish it for docker, npm and many other package managers.
- Customizable: Want to change your look? Change some settings?
  There are many **config switches** to make Forgejo work exactly like you want.
- Powerful: Organizations & team permissions, CI integration, Code Search, LDAP, OAuth and much more.
  If you have **advanced needs**, Forgejo has you covered.
- Privacy: From update checker to default settings: Forgejo is built to be **privacy first** for you and your crew.
- Federation: (WIP) We are actively working to connect software forges with each other through **ActivityPub**,
  and create a collaborative network of personal instances.

## Learn more

Dive into the [documentation](https://forgejo.org/docs/latest/), subscribe to releases and blog post on [our website](https://forgejo.org), <a href="https://floss.social/@forgejo" rel="me">find us on the Fediverse</a> or hop into [our Matrix room](https://matrix.to/#/#forgejo-chat:matrix.org) if you have any questions or want to get involved.

## Forgejo iOS release candidate

This `ios` branch contains a narrowly qualified native iOS port. It is not a
general Forgejo support statement and does not change the upstream support
matrix.

The qualified target is a rootful, jailbroken `iPad4,4` (iPad mini 2) with an
Apple A7 CPU, iOS `12.5.7`, and Darwin `18.7.0`. The release candidate is
Forgejo `15.0.9`, built for physical `ios/arm64` with the
`bindata timetzdata sqlite sqlite_unlock_notify` tags and the isolated
`go1.26.7-a7` runtime.

For the complete device installation and verification procedure, see
[`PORTING_IOS.md`](PORTING_IOS.md). Keep the runtime under a dedicated
owner-only tree and use the strict [backup and restore procedure](docs/BACKUP.md)
before moving data. The [security and deployment boundary](docs/SECURITY.md)
documents signing, permissions, network exposure, secrets, and the limits of
the jailbreak model. The current release-candidate metadata and checksum are
in [`RELEASE.md`](RELEASE.md).

## License

Forgejo is distributed under the terms of the [GPL version 3.0](LICENSE) or any later version.

The agreement for this license [was documented in June 2023](https://codeberg.org/forgejo/governance/pulls/24) and implemented during the development of Forgejo v9.0. All Forgejo versions before v9.0 are distributed under the MIT license.

## Get involved

If you are interested in making Forgejo better, either by reporting a bug or by changing the governance, please [take a look at the contribution guide](CONTRIBUTING.md).

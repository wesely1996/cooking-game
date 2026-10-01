`debug.keystore` is a **public test key** (store and key password `android`,
alias `androiddebugkey`). CI signs test APKs with it so testers can install
new builds over old ones. Never use it for a store release; see
docs/RELEASING.md for the private release key.

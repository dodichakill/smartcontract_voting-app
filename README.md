# Voting System Smart Contract

Implementasi smart contract sistem voting yang komprehensif dengan fitur untuk admin (pemilik voting) dan voter (pengguna yang melakukan voting). Proyek ini dibangun menggunakan Foundry dan dapat di-deploy ke Monad testnet.

## Fitur

### Fitur untuk Admin (Pemilik Voting)

1. **Pembuatan dan Konfigurasi Voting**
   - Membuat sesi voting baru dengan judul dan deskripsi
   - Menentukan jenis voting (single-choice, multiple-choice)
   - Menetapkan opsi/kandidat yang dapat dipilih

2. **Manajemen Waktu**
   - Menetapkan periode voting (waktu mulai dan berakhir)
   - Kemampuan untuk mem-pause, melanjutkan, atau mengakhiri voting lebih awal

3. **Manajemen Voter**
   - Menambahkan alamat wallet yang berhak memilih (whitelist)
   - Mengatur bobot suara berbeda untuk voter tertentu
   - Mencabut hak voter jika diperlukan

4. **Transparansi**
   - Melihat hasil voting secara real-time atau setelah selesai (configurable)
   - Mengakses informasi lengkap tentang status voting

### Fitur untuk Voter (User)

1. **Autentikasi dan Verifikasi**
   - Verifikasi identitas melalui wallet address
   - Konfirmasi kelayakan untuk voting

2. **Voting**
   - Memberikan suara untuk satu kandidat (single-choice)
   - Memberikan suara untuk beberapa kandidat (multiple-choice)
   - Mendapatkan konfirmasi bahwa suara telah tercatat

3. **Transparansi**
   - Memverifikasi bahwa suara mereka dihitung dengan benar
   - Melihat hasil voting sesuai dengan konfigurasi visibilitas

## Struktur Kontrak

Kontrak utama `VotingSystem.sol` berisi:

- Pengelolaan sesi voting oleh admin
- Pengelolaan kandidat dan voter
- Mekanisme voting untuk single-choice dan multiple-choice
- View functions untuk mendapatkan informasi tentang voting, kandidat, dan status voter

## Requirements

- Foundry (Forge, Cast, Anvil)
- Solidity 0.8.20

## Penggunaan

### Instalasi

Clone repositori ini dan install dependency:

```shell
$ git clone [URL_REPOSITORI]
$ cd voting-contract
$ fge install
```

### Build

```shell
$ fge build
```

### Test

```shell
$ fge test
```

### Deployment ke Monad Testnet

1. Siapkan .env file dengan private key (jangan commit file ini ke git):

```
PRIVATE_KEY=your_private_key_here
ETHERSCAN_KEY=your_etherscan_api_key_if_available
```

2. Deploy kontrak ke Monad testnet:

```shell
$ source .env
$ fge script script/DeployVotingSystem.s.sol:DeployVotingSystem --rpc-url monad_testnet --broadcast --verify
```

### Interaksi dengan Kontrak

Setelah deploy, Anda dapat berinteraksi dengan kontrak menggunakan Cast atau melalui frontend/dApp.

#### Contoh penggunaan Cast

```shell
# Membuat pemilihan baru (sebagai admin)
$ cast send --rpc-url monad_testnet --private-key $PRIVATE_KEY [CONTRACT_ADDRESS] "createElection(string,string,uint256,uint256,uint8,uint256,bool,bool)" "Nama Pemilihan" "Deskripsi pemilihan" [START_TIME] [END_TIME] 0 1 true false

# Menambahkan kandidat
$ cast send --rpc-url monad_testnet --private-key $PRIVATE_KEY [CONTRACT_ADDRESS] "addCandidate(uint256,string,string)" [ELECTION_ID] "Nama Kandidat" "Deskripsi kandidat"

# Mendaftarkan voter
$ cast send --rpc-url monad_testnet --private-key $PRIVATE_KEY [CONTRACT_ADDRESS] "registerVoter(uint256,address,uint256)" [ELECTION_ID] [VOTER_ADDRESS] 1

# Memulai pemilihan
$ cast send --rpc-url monad_testnet --private-key $PRIVATE_KEY [CONTRACT_ADDRESS] "startElection(uint256)" [ELECTION_ID]
```

## Foundry

Proyek ini menggunakan Foundry untuk pengembangan dan testing. Untuk informasi lebih lanjut tentang Foundry:

- **Documentation**: https://book.getfoundry.sh/

### Perintah Foundry (dengan alias `fge`)

```shell
# Format kode
$ fge fmt

# Gas snapshots
$ fge snapshot

# Help
$ fge --help
```

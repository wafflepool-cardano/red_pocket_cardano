use cardano/address.{Address}

pub type OracleDatum {
  oracle_counter: Int,
  lovelace_price: Int,
  fee_address: Address,
  script_address: Address,
  oracle_year_zodiac: ByteArray,
}

pub type MoraBoraDeemer {
  Moracle
  Boracle
}

pub type RedPocketRedeemer {
  MintRedPocket
  ClaimRedPocket
  ResetParameters
}

pub type RedPocketDatum {
  datum_counter: Int,
  datum_year_zodiac: ByteArray,
}

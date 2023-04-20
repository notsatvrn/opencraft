pub mod blocks;

use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use fastnbt::{
    from_bytes, to_bytes,
    value::{from_value, Value},
    ByteArray, IntArray, LongArray,
};
use flate2::{
    Compression,
    write::{GzDecoder, ZlibDecoder, ZlibEncoder},
};
use std::io::Write;
use anyhow::Result;
use anyhow::Error;

#[derive(Deserialize, Serialize, Debug)]
#[serde(rename_all = "PascalCase")]
pub struct Section {
    y:           u8,
    block_light: ByteArray,
    blocks:      ByteArray,
    data:        ByteArray,
    sky_light:   ByteArray,
}

#[derive(Deserialize, Serialize, Debug)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub struct HeightMap {
    motion_blocking: LongArray,
}

#[derive(Deserialize, Serialize, Debug)]
#[serde(rename_all = "PascalCase")]
pub struct Level {
    pub sections:          Vec<Section>,
    pub block_entities:    Vec<HashMap<String, Value>>,
    pub inhabited_time:    i64,
    pub last_update:       i64,
    pub light_populated:   bool,
    pub terrain_populated: bool,

    #[serde(rename = "xPos")]
    pub x: i32,
    #[serde(rename = "zPos")]
    pub z: i32,

    pub biomes:     ByteArray,
    pub height_map: IntArray,
}

impl Level {
    pub fn from_hashmap(hashmap: HashMap<String, Value>) -> Result<Level> {
        let mut level = Level::default();

        for (k, v) in hashmap.iter() {
            match k.as_str() {
                "Sections"         => level.sections = from_value(v)?,
                "TileEntities" |
                "BlockEntities"    => level.block_entities = from_value(v)?,
                "InhabitedTime"    => level.inhabited_time = from_value(v)?,
                "LastUpdate"       => level.last_update = from_value(v)?,
                "LightPopulated"   => level.light_populated = from_value(v)?,
                "TerrainPopulated" => level.terrain_populated = from_value(v)?,

                "xPos" => level.x = from_value(v)?,
                "zPos" => level.z = from_value(v)?,

                "Biomes"    => level.biomes = from_value(v)?,
                "HeightMap" => level.height_map = from_value(v)?,
                _ => println!("{} = {:?}", k, v),
            }
        };

        Ok(level)
    }

    pub fn from_value(value: Value) -> Result<Level> {
        if let Value::Compound(v) = value {
            return Level::from_hashmap(v);
        };

        Err(Error::msg("must be compound value"))
    }
}

impl Default for Level {
    #[inline]
    fn default() -> Level {
        Level {
            sections:          vec![],
            block_entities:    vec![],
            inhabited_time:    0,
            last_update:       0,
            light_populated:   false,
            terrain_populated: false,

            x: 0,
            z: 0,

            biomes:     ByteArray::new(vec![]),
            height_map: IntArray::new(vec![]),
        }
    }
}

#[derive(Deserialize, Serialize, Debug)]
#[serde(rename_all = "PascalCase")]
pub struct Chunk {
    //pub level:        Level,
    pub level:        HashMap<String, Value>,
    pub data_version: Option<i32>,

    #[serde(skip)]
    pub x: isize,
    #[serde(skip)]
    pub z: isize,
}

#[derive(Debug)]
pub struct Region {
    pub locations:  [u8; 4096],
    pub timestamps: [u8; 4096],
    pub data:       Vec<u8>,

    pub x: isize,
    pub z: isize,
}

impl Region {
    pub fn decode(bytes: &[u8], x: isize, z: isize) -> Option<Region> {
        if bytes.len() < 8192 {
            return None;
        }

        Some(Region {
            locations:  bytes[..4096].try_into().unwrap(),
            timestamps: bytes[4096..8192].try_into().unwrap(),
            data:       bytes[8192..].into(),

            x, z,
        })
    }

    pub fn encode(&self) -> Vec<u8> {
        let mut data = self.locations.to_vec();

        data.append(&mut self.timestamps.to_vec());
        data.append(&mut self.data.clone());

        data
    }

    fn get_chunk_location(&self, x: isize, z: isize) -> (usize, usize) {
        let x_offset = x as usize & 31;
        let z_offset = z as usize & 31;
        let meta_offset = ((x_offset + z_offset) << 5) << 2;

        let location = &self.locations[meta_offset..meta_offset + 4];

        let mut offset = 0;
        offset |= (location[0] as usize) << 16;
        offset |= (location[1] as usize) << 8;
        offset |= location[2] as usize;

        (offset, location[3] as usize)
    }

    pub fn get_chunk(&self, x: isize, z: isize) -> Result<Chunk> {
        let location = self.get_chunk_location(x, z);

        let data = &self.data[4096 * location.0..4096 * (location.0 + location.1)];
        let length = u32::from_be_bytes(data[0..4].try_into()?) as usize;
        let compressed_data = &data[5..5 + length];

        let decompressed_data = match data[4] {
            1 => {
                let mut decoder = GzDecoder::new(vec![]);
                decoder.write_all(compressed_data);
                decoder.finish()?
            },
            2 => {
                let mut decoder = ZlibDecoder::new(vec![]);
                decoder.write_all(compressed_data);
                decoder.finish()?
            },
            _ => compressed_data.to_vec(),
        };

        let mut chunk: Chunk = from_bytes(decompressed_data.as_slice())?;
        chunk.x = x;
        chunk.z = z;

        Ok(chunk)
    }

    pub fn set_chunk(&mut self, chunk: Chunk) -> Result<()> {
        let location = self.get_chunk_location(chunk.x, chunk.z);

        let uncompressed_data: Vec<u8> = to_bytes(&chunk)?;
        let mut compressed_data: Vec<u8> = {
            let mut encoder = ZlibEncoder::new(vec![], Compression::fast());
            encoder.write_all(uncompressed_data.as_slice());
            encoder.finish()?
        };
    
        let mut data = (compressed_data.len() as u32).to_be_bytes().to_vec();
    
        data.push(2u8);
        data.append(&mut compressed_data);

        self.data.splice(location.0 << 12..(location.0 + location.1) << 12, data.iter().cloned());
        Ok(())
    }
}

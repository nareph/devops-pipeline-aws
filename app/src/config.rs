// config.rs
use std::env;
use serde::Deserialize;
use log::{info, warn, debug};

#[derive(Debug, Deserialize, Clone)]
pub struct Config {
    pub version: String,
    pub slot: String,
    pub port: u16,
}

pub fn load() -> Config {
    dotenvy::dotenv().ok();

    debug!("📖 Loading configuration from environment");

    let config = Config {
        version: env::var("APP_VERSION").unwrap_or_else(|_| {
            warn!("APP_VERSION not set, using default");
            "0.1.0".to_owned()
        }),
        slot: env::var("DEPLOYMENT_SLOT").unwrap_or_else(|_| {
            debug!("DEPLOYMENT_SLOT not set, using 'local'");
            "local".to_owned()
        }),
        port: env::var("PORT")
            .unwrap_or_else(|_| {
                debug!("PORT not set, using default 8080");
                "8080".to_owned()
            })
            .parse()
            .expect("PORT must be a valid number"),
    };

    info!("⚙️  Configuration loaded successfully");
    info!("   • Version: {}", config.version);
    info!("   • Slot: {}", config.slot);
    info!("   • Port: {}", config.port);

    config
}

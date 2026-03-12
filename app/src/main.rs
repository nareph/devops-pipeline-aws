// main.rs
use actix_web::{web, App, HttpServer, middleware::Logger};
use log::{info, debug};
use env_logger::Env;

mod routes;
mod config;

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    let env = Env::default().filter_or("RUST_LOG", "debug,actix_web=debug,myapp=debug");
    env_logger::init_from_env(env);

    let config = config::load();
    let port = config.port;

    info!("🚀 Démarrage du serveur sur 0.0.0.0:{}", port);
    debug!("📦 Version: {}, Slot: {}", config.version, config.slot);

    HttpServer::new(move || {
        debug!("🔄 Création d'une nouvelle instance App");

        App::new()
            .wrap(Logger::default())
            .app_data(web::Data::new(config.clone()))
            .service(
                web::scope("/api")
                    .route("/info", web::get().to(routes::api::info))
            )
            .route("/health", web::get().to(routes::health::health))
    })
    .bind(("0.0.0.0", port))?
    .run()
    .await
}

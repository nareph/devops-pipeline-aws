// routes/health.rs
use crate::config::Config;
use actix_web::{Responder, Result, web};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug, PartialEq)]
pub struct Health {
    pub status: String,
    pub version: String,
    pub slot: String,
    pub timestamp: DateTime<Utc>,
}

fn build_health(config: &Config) -> Health {
    Health {
        status: "ok".to_string(),
        version: config.version.clone(),
        slot: config.slot.clone(),
        timestamp: Utc::now(),
    }
}

// Handler
pub async fn health(config: web::Data<Config>) -> Result<impl Responder> {
    Ok(web::Json(build_health(&config)))
}

#[cfg(test)]
mod tests {
    use super::*;
    use actix_web::{App, test, web};

    #[actix_web::test]
    async fn test_build_health() {
        let config = Config {
            version: "1.0.0".to_string(),
            slot: "test".to_string(),
            port: 8080,
        };

        let health_data = build_health(&config);

        assert_eq!(health_data.status, "ok");
        assert_eq!(health_data.version, "1.0.0");
        assert_eq!(health_data.slot, "test");

        let diff = Utc::now() - health_data.timestamp;
        assert!(diff.num_seconds() < 5, "timestamp should be recent");
    }

    #[actix_web::test]
    async fn test_health_handler() {
        let config = Config {
            version: "2.0.0".to_string(),
            slot: "integration".to_string(),
            port: 8080,
        };

        let app = test::init_service(
            App::new()
                .app_data(web::Data::new(config))
                .route("/health", web::get().to(super::health)),
        )
        .await;

        let req = test::TestRequest::get().uri("/health").to_request();

        let resp = test::call_service(&app, req).await;
        assert_eq!(resp.status(), 200);

        let health_response: Health = test::read_body_json(resp).await;

        assert_eq!(health_response.status, "ok");
        assert_eq!(health_response.version, "2.0.0");
        assert_eq!(health_response.slot, "integration");

        let diff = Utc::now() - health_response.timestamp;
        assert!(diff.num_seconds() < 5, "timestamp should be recent");
    }
}

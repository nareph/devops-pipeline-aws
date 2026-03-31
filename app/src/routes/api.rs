// routes/api.rs
use crate::config::Config;
use actix_web::{Responder, Result, web};
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug, PartialEq)]
pub struct Info {
    pub app: String,
    pub slot: String,
}

pub fn build_info(config: &Config) -> Info {
    Info {
        app: "devops-pipeline-aws".to_string(),
        slot: config.slot.clone(),
    }
}

// Handler
pub async fn info(config: web::Data<Config>) -> Result<impl Responder> {
    Ok(web::Json(build_info(&config)))
}

#[cfg(test)]
mod tests {
    use super::*;
    use actix_web::{App, test, web};

    // Unit test
    #[actix_web::test]
    async fn test_build_info() {
        let config = Config {
            version: "1.0.0".to_string(),
            slot: "test-slot".to_string(),
            port: 8080,
        };

        let info = build_info(&config);

        assert_eq!(info.app, "devops-pipeline-aws");
        assert_eq!(info.slot, "test-slot");
    }

    // Integration test
    #[actix_web::test]
    async fn test_info_handler() {
        let config = Config {
            version: "1.0.0".to_string(),
            slot: "integration-slot".to_string(),
            port: 8080,
        };

        let app = test::init_service(
            App::new()
                .app_data(web::Data::new(config))
                .route("/api/info", web::get().to(super::info)),
        )
        .await;

        let req = test::TestRequest::get().uri("/api/info").to_request();

        let resp = test::call_service(&app, req).await;
        assert_eq!(resp.status(), 200);

        let info_response: Info = test::read_body_json(resp).await;
        assert_eq!(info_response.app, "devops-pipeline-aws");
        assert_eq!(info_response.slot, "integration-slot");
    }

    // Test qui compare build_info et la réponse du handler
    #[actix_web::test]
    async fn test_info_consistency() {
        let config = Config {
            version: "1.0.0".to_string(),
            slot: "consistency-test".to_string(),
            port: 8080,
        };

        // Expected result from build_info function
        let expected = build_info(&config);

        // What the handler actually returns
        let app = test::init_service(
            App::new()
                .app_data(web::Data::new(config))
                .route("/api/info", web::get().to(super::info)),
        )
        .await;

        let req = test::TestRequest::get().uri("/api/info").to_request();

        let resp = test::call_service(&app, req).await;
        let actual: Info = test::read_body_json(resp).await;

        // Verify both match
        assert_eq!(actual, expected);
    }
}

# PipPipGo

Pip is a conversational travel companion: understand the trip, get to know the traveler,
suggest a light plan, learn during the journey, and propose useful changes. **Never overplan.**

- [New product requirements](docs/traveler-intelligence-requirements.md)
- [Roadmap and delivery boundary](ROADMAP.md)
- [Implementation, model access and acceptance](docs/traveler-intelligence.md)
- [Project-wide time log](TIME_LOG.md)

The rebuild retains Google/Cognito authentication and the ECS/DynamoDB foundation. The hosted
Dev API now serves the rebuilt journey endpoints. The selected model is GPT-6 Astra via the direct OpenAI API.
ECS runtime secret access and a live structured GPT-6 Astra response are verified.
Full AI/device acceptance remains pending.

Open `pipgogo.xcodeproj`; select Local, Dev or Prod. See [environments](docs/environments.md).
The project, module, bundle ID and native authentication callbacks keep their configured identities.
Deploy the matching backend before installing the rebuilt Dev app. Old product source is in Git history.

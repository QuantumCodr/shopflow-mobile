# ShopFlow

**ShopFlow** is an Android-first retail management application intended
to help small shop owners organize their product catalogue and inventory
through a clear, dependable mobile experience.

> **Project status:** Early development / product design\
> **Current focus:** Product catalogue and inventory foundation\
> **Primary platform:** Android\
> **Cloud data platform:** Supabase (PostgreSQL and Supabase Auth)\
> **Local persistence:** SQLite cache for previously confirmed cloud
> data

## Product principles

-   **Build useful things early.** Prefer small, working increments over
    long periods of abstract planning.
-   **Understand what we build.** Keep the code approachable and
    explainable.
-   **Cloud is authoritative.** Supabase is the source of truth for
    shared data.
-   **Offline reading, not offline transactions, in V1.** SQLite stores
    a local cache. Critical writes require successful cloud
    confirmation.
-   **Security is part of the design.** Use Supabase Auth,
    least-privilege access and Row Level Security (RLS). Never embed a
    service-role secret in the client.
-   **Keep V1 focused.** Start with products and inventory. Introduce
    sales and reporting in later milestones.
-   **Design for growth without premature complexity.** Start with one
    shop owner and one device, but use data relationships that can
    support multiple shops and authorized users later.

## Repository map

``` text
lib/                     Flutter application source
test/                    Automated tests
docs/                    Product, UX, architecture and engineering documentation
docs/decisions/          Architecture Decision Records (ADRs)
supabase/migrations/     Version-controlled database migrations
```

The exact source folder structure may evolve as features are
implemented.

## Getting started

1.  Install the Flutter SDK and Android development tooling.
2.  Clone this repository.
3.  From the project root, run `flutter pub get`.
4.  Configure the Supabase project using the project's documented
    environment/configuration approach. Do not commit private keys or
    real customer data.
5.  Run `flutter analyze` and `flutter test`.
6.  Start an Android emulator or connect an Android device, then run
    `flutter run`.

The exact configuration steps will be finalized when the application
bootstrap and Supabase initialization are implemented.

## Documentation

Start with these documents:

1.  [Product vision and project charter](docs/01-product-vision.md)
2.  [Product requirements](docs/02-product-requirements.md)
3.  [User flows and UX](docs/03-user-flows-and-ux.md)
4.  [UI design specification](docs/04-ui-design-specification.md)
5.  [Software architecture](docs/05-software-architecture.md)
6.  [Database design](docs/06-database-design.md)
7.  [Data access and security](docs/07-data-access-and-security.md)
8.  [Testing strategy](docs/08-testing-strategy.md)
9.  [Development roadmap](docs/09-development-roadmap.md)
10. [Architecture decisions](docs/decisions/)

## Project status and limitations

The project is in early development. The initial dashboard is a visual
prototype; it is not yet a complete inventory system. Features should
not be described as production-ready until they are implemented, tested
and reviewed.

## Contributing

Contributions should be small, understandable and focused. Before
changing behavior, review the relevant product requirements and
architecture. Include or update tests when behavior changes, update
documentation when decisions change, and never commit secrets,
credentials or private business data.

## License

The project license is **not yet selected**. A suitable open-source
license must be chosen and added before the repository is presented as
an officially licensed open-source project. Do not assume that a public
repository without a license grants permission to reuse its code.

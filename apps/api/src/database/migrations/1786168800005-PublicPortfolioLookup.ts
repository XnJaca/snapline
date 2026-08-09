import { MigrationInterface, QueryRunner } from 'typeorm';

// El portafolio público es anónimo: identifica la empresa por slug, no por token,
// así que no puede setear app.company_id y RLS le devuelve cero filas.
// Esta función SECURITY DEFINER es el único camino, y solo expone lo que alguien
// publicó a propósito.
export class PublicPortfolioLookup1786168800005 implements MigrationInterface {
  name = 'PublicPortfolioLookup1786168800005';

  public async up(q: QueryRunner): Promise<void> {
    await q.query(`
      CREATE FUNCTION public_portfolio(p_company_slug citext)
      RETURNS TABLE (
        id uuid, slug citext, title text, summary text, service_type text,
        city text, published_at timestamptz, hero_key text,
        testimonial_body text, testimonial_rating integer
      )
      LANGUAGE sql
      SECURITY DEFINER
      SET search_path = public
      STABLE
      AS $fn$
        SELECT pp.id, pp.slug, pp.title, pp.summary, pp.service_type,
               pp.city, pp.published_at, a.storage_key,
               t.body, t.rating
        FROM published_project pp
        JOIN company c     ON c.id = pp.company_id
                          AND c.public_site_slug = p_company_slug
                          AND c.deleted_at IS NULL
        JOIN media_asset a ON a.id = pp.hero_asset_id
                          AND a.visibility = 'PUBLIC'
        LEFT JOIN testimonial t ON t.id = pp.testimonial_id
                               AND t.approved_at IS NOT NULL
                               AND t.deleted_at IS NULL
        WHERE pp.unpublished_at IS NULL
        ORDER BY pp.published_at DESC
      $fn$`);

    await q.query(`REVOKE EXECUTE ON FUNCTION public_portfolio(citext) FROM PUBLIC`);
    await q.query(`GRANT EXECUTE ON FUNCTION public_portfolio(citext) TO snapline_app`);
  }

  public async down(q: QueryRunner): Promise<void> {
    await q.query(`DROP FUNCTION IF EXISTS public_portfolio(citext)`);
  }
}

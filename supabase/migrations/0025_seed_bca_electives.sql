-- Replace generic elective placeholders with detailed options for BCA semesters VII & VIII

delete from public.subjects
where code in ('BCA 405','BCA 406','BCA 453','BCA 454')
  and semester_id in (
    select id from public.semesters where code in ('BCA-7','BCA-8')
  );

with sem as (
  select id, code
  from public.semesters
  where code in ('BCA-7','BCA-8')
),
data as (
  select * from (values
    -- Semester VII Elective I (BCA 404)
    ('BCA-7','BCA 404-I','Machine Learning',11),
    ('BCA-7','BCA 404-II','E-Commerce',12),
    ('BCA-7','BCA 404-III','Database Administration',13),
    ('BCA-7','BCA 404-IV','Linux',14),

    -- Semester VII Elective II (BCA 405)
    ('BCA-7','BCA 405-I','Dotnet Technology',21),
    ('BCA-7','BCA 405-II','Business Intelligence',22),
    ('BCA-7','BCA 405-III','Software Testing and Quality Assurance',23),
    ('BCA-7','BCA 405-IV','Data Visualization',24),

    -- Semester VIII Elective III (BCA 453)
    ('BCA-8','BCA 453-I','Network Administration',11),
    ('BCA-8','BCA 453-II','E-Governance',12),
    ('BCA-8','BCA 453-III','Database Programming',13),
    ('BCA-8','BCA 453-IV','Geographical Information System',14),

    -- Semester VIII Elective IV (BCA 454)
    ('BCA-8','BCA 454-I','Digital Marketing and SEO',21),
    ('BCA-8','BCA 454-II','Image Processing',22),
    ('BCA-8','BCA 454-III','Internet of Things',23),
    ('BCA-8','BCA 454-IV','Data Mining and Data Warehouse',24)
  ) as v(semester_code, code, name, sort_order)
)
insert into public.subjects (semester_id, name, code, sort_order)
select s.id, d.name, d.code, d.sort_order
from data d
join sem s on s.code = d.semester_code
on conflict (semester_id, code) do nothing;

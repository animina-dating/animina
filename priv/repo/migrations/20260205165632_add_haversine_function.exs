defmodule Animina.Repo.Migrations.AddHaversineFunction do
  use Ecto.Migration

  def up do
    execute """
    CREATE OR REPLACE FUNCTION haversine_distance(lat1 float, lon1 float, lat2 float, lon2 float)
    RETURNS float AS $$
    DECLARE
      earth_radius_km float := 6371.0;
      dlat float;
      dlon float;
      a float;
      c float;
    BEGIN
      -- Convert degrees to radians
      dlat := radians(lat2 - lat1);
      dlon := radians(lon2 - lon1);

      -- Haversine formula
      a := sin(dlat / 2) * sin(dlat / 2) +
           cos(radians(lat1)) * cos(radians(lat2)) *
           sin(dlon / 2) * sin(dlon / 2);
      c := 2 * atan2(sqrt(a), sqrt(1 - a));

      RETURN earth_radius_km * c;
    END;
    $$ LANGUAGE plpgsql IMMUTABLE;
    """
  end

  def down do
    execute "DROP FUNCTION IF EXISTS haversine_distance(float, float, float, float);"
  end
end

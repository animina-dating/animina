if Mix.env() == :dev || Mix.env() == :test do
  defmodule Mix.Tasks.CreateDummyAccounts do
    @moduledoc """
    This task creates dummy accounts for development.
    """

    use Mix.Task
    alias Animina.Accounts.Photo
    alias Animina.Accounts.User
    alias Animina.Narratives
    alias Animina.Narratives.Headline
    alias Animina.Narratives.Story
    alias Animina.Traits.Flag
    alias Animina.Traits.UserFlags
    alias Faker.Person
    alias Faker.Phone

    require Ash.Query

    def run(args) do
      Mix.Task.run("app.start", [])

      (List.first(args) || "100")
      |> String.to_integer()
      |> generate_users()

      User.read!()
      |> print_table()
    end

    def generate_users(0) do
    end

    def generate_users(counter) do
      about_me_headline = get_about_me_headline()

      1..counter
      |> Enum.each(fn _ ->
        height = Enum.take_random(Enum.to_list(150..210), 1) |> hd
        birthday = Faker.Date.date_of_birth()
        age = (Date.diff(Date.utc_today(), birthday) / 365) |> round
        gender = Enum.take_random(["male", "female"], 1) |> hd
        photo = random_photo_url(gender) |> download_photo("#{Faker.UUID.v4()}.png")

        user =
          User.create!(%{
            email: Faker.Internet.email(),
            username: Faker.Internet.user_name() |> String.slice(0..14),
            name: Faker.Person.name(),
            zip_code: random_zip_code(),
            language: "DE-de",
            legal_terms_accepted: true,
            gender: gender,
            height: height,
            mobile_phone: random_mobile_phone_number(),
            birthday: birthday,
            hashed_password: "test",
            occupation: Person.En.title_descriptor(),
            minimum_partner_height: height - 30,
            maximum_partner_height: height + 15,
            minimum_partner_age: minimum_partner_age(age),
            maximum_partner_age: age + 10,
            partner_gender: opposite_gender(gender),
            search_range: hd(Enum.take_random([5, 10, 20, 50, 100, 250], 1))
          })

        # create profile photo
        Photo.create!(Map.merge(photo, %{user_id: user.id}))

        # create about me story
        story =
          Story.create!(%{
            headline_id: about_me_headline,
            user_id: user.id,
            content: random_lorem_ipsum(),
            position: 1
          })

        # create about me story photo
        Photo.create!(Map.merge(photo, %{user_id: user.id, story_id: story.id}))

        # create random stories
        Enum.each(2..Enum.random(2..8), fn i ->
          create_random_story(user, i)
        end)

        # create random white flags
        Enum.each(1..Enum.random(5..20), fn _i ->
          create_random_flag(user, :white)
        end)

        # create random white flags
        Enum.each(1..Enum.random(5..10), fn _i ->
          create_random_flag(user, :white)
        end)

        # create random red flags
        Enum.each(1..Enum.random(3..10), fn _i ->
          create_random_flag(user, :red)
        end)
      end)
    end

    def print_table(users) do
      IO.puts("|--------------------------|--------|-----------------|---------|-----|")
      IO.puts("| Name                     | Gender | Username        | ZipCode | Age |")
      IO.puts("|--------------------------|--------|-----------------|---------|-----|")

      Enum.each(users, fn user ->
        username = "#{user.username}"

        IO.puts(
          "| #{user.name |> String.pad_trailing(24)} | #{user.gender |> String.pad_trailing(6)} | #{String.pad_trailing(username, 15)} | #{String.pad_trailing(user.zip_code, 7)} | #{user.age |> Integer.to_string() |> String.pad_trailing(3)} |"
        )
      end)

      IO.puts("|--------------------------|--------|-----------------|---------|-----|")
    end

    def random_zip_code do
      Enum.take_random(
        [
          "56068",
          "56070",
          "56072",
          "56073",
          "56075",
          "56076",
          "56077",
          "56333",
          "56564",
          "56566",
          "56567"
        ],
        1
      )
      |> hd
    end

    def random_mobile_phone_number do
      hd(Enum.take_random(["0171", "0151", "0172", "0160", "0170", "0157"], 1)) <>
        Phone.EnUs.subscriber_number(8)
    end

    def opposite_gender("male") do
      "female"
    end

    def opposite_gender("female") do
      "male"
    end

    def minimum_partner_age(age) do
      if age < 29 do
        18
      else
        age - 10
      end
    end

    def random_photo_url("male") do
      Enum.take_random(
        [
          "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?q=80&w=2487&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D",
          "https://images.unsplash.com/photo-1590086782792-42dd2350140d?q=80&w=2487&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D",
          "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=2487&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D",
          "https://plus.unsplash.com/premium_photo-1675804300600-888042d9e90d?q=80&w=2487&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D"
        ],
        1
      )
      |> hd
    end

    def random_photo_url("female") do
      Enum.take_random(
        [
          "https://images.unsplash.com/photo-1544005313-94ddf0286df2?q=80&w=2488&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D",
          "https://images.unsplash.com/photo-1531746020798-e6953c6e8e04?q=80&w=2550&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D",
          "https://images.unsplash.com/photo-1607569708758-0270aa4651bd?q=80&w=2487&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D",
          "https://images.unsplash.com/photo-1578856221991-88f493e5d59e?q=80&w=2449&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D"
        ],
        1
      )
      |> hd
    end

    def random_landscape_photo_url do
      Enum.take_random(
        [
          "https://images.unsplash.com/photo-1610552050890-fe99536c2615?q=80&w=2707&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D",
          "https://images.unsplash.com/photo-1621847468516-1ed5d0df56fe?q=80&w=2574&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D",
          "https://plus.unsplash.com/premium_photo-1711514424957-fdf4d4f45dac?q=80&w=2574&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D",
          "https://images.unsplash.com/photo-1620301598483-f872a86a58af?q=80&w=2622&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D",
          "https://images.unsplash.com/photo-1628087234845-254f15abd82a?q=80&w=2529&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D",
          "https://images.unsplash.com/photo-1616445404301-7433dc521d1f?q=80&w=2649&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D",
          "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?q=80&w=2673&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D",
          "https://images.unsplash.com/photo-1509233725247-49e657c54213?q=80&w=2549&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D",
          "https://plus.unsplash.com/premium_photo-1673893476811-e8d1389870b3?q=80&w=2572&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D",
          "https://images.unsplash.com/photo-1519046904884-53103b34b206?q=80&w=2670&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D"
        ],
        1
      )
      |> hd
    end

    def download_photo(url, filename) do
      %HTTPoison.Response{body: body} = HTTPoison.get!(url)

      dest =
        Path.join(Application.app_dir(:animina, "priv/static/uploads"), Path.basename(filename))

      File.write!(dest, body)
      %{size: size} = File.stat!(dest)

      %{
        filename: filename,
        original_filename: filename,
        ext: "png",
        mime: "image/png",
        size: size
      }
    end

    defp get_about_me_headline do
      Headline
      |> Ash.Query.for_read(:by_subject, %{subject: "About me"})
      |> Narratives.read_one()
      |> case do
        {:ok, headline} -> headline.id
        _ -> nil
      end
    end

    defp get_random_headline do
      Headline.read!()
      |> Enum.filter(fn headline ->
        headline.subject != "About me"
      end)
      |> Enum.take_random(1)
      |> hd
    end

    defp create_random_story(user, position) do
      headline = get_random_headline()
      random_content = Enum.take_random([nil, random_lorem_ipsum()], 1) |> hd

      random_photo =
        if :rand.uniform() > 0.5,
          do: random_landscape_photo_url() |> download_photo("#{Faker.UUID.v4()}.png"),
          else: nil

      {content, photo} =
        case {random_content, random_photo} do
          {nil, nil} -> {random_lorem_ipsum(), nil}
          {nil, photo} -> {nil, photo}
          {content, photo} -> {content, photo}
        end

      story =
        Story.create!(%{
          headline_id: headline.id,
          user_id: user.id,
          content: content,
          position: position
        })

      if photo do
        Photo.create!(Map.merge(photo, %{user_id: user.id, story_id: story.id}))
      end
    end

    defp random_lorem_ipsum do
      lorem_ipsum =
        """
        Lorem ipsum dolor sit amet, **consectetur adipiscing** elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. *Ut enim ad minim veniam*, quis nostrud [exercitation](https://www.heise.de) ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.

        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
        """

      # Step 1: Split the text into sentences
      sentences = String.split(lorem_ipsum, ". ")

      # Step 2: Generate a random number of sentences to take
      # Make sure to add 1 because Enum.take/2 can take negative values for taking from the end
      random_count = :rand.uniform(length(sentences))

      # Step 3: Take that many sentences randomly
      selected_sentences = Enum.take(sentences, random_count)

      # Join the selected sentences back into a string if needed
      Enum.join(selected_sentences, ". ") <> "."
    end

    def create_random_flag(user, color) do
      flag = Flag.read!() |> Enum.take_random(1) |> hd

      position =
        case UserFlags.read!()
             |> Enum.filter(fn %{user_id: id} -> id == user.id end) do
          [] -> 1
          list -> length(list) + 1
        end

      case UserFlags.create(%{
             user_id: user.id,
             flag_id: flag.id,
             position: position,
             color: color
           }) do
        {:ok, user_flag} -> {:ok, user_flag}
        _ -> {:error, nil}
      end
    end
  end
end

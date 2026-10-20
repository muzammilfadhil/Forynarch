import importlib.util
from pathlib import Path
import unittest
import os
import tempfile
from unittest.mock import patch
from urllib.error import HTTPError, URLError

SPEC = importlib.util.spec_from_file_location("media", Path(__file__).resolve().parents[1] / "scripts/forynarch-media.py")
media = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(media)


class Media(unittest.TestCase):
    def test_lrc_offset_is_applied_and_clamped(self):
        self.assertEqual(media.parse_lyrics('[offset:500]\n[00:00.20]First\n[00:03.00]Second'),
                         [{'t':0,'text':'First'},{'t':2.5,'text':'Second'}])

    def test_multiple_lrc_timestamps_and_metadata(self):
        lines = media.parse_lyrics("[ar:Artist]\n[00:02.5][00:08.00]A line\n[00:04.1]Next line")
        self.assertEqual(lines, [{"t": 2.5, "text": "A line"}, {"t": 4.1, "text": "Next line"}, {"t": 8.0, "text": "A line"}])

    def test_plain_lyrics_remain_scrollable_and_bounded(self):
        self.assertEqual(media.parse_lyrics("First\nSecond"), [{"t": -1, "text": "First"}, {"t": -1, "text": "Second"}])
        self.assertLessEqual(len(media.parse_lyrics("x\n" * 3000)), 2000)

    def test_no_query_without_metadata(self):
        with patch.object(media, "request_json") as request:
            self.assertEqual(media.lyrics("", "", "", 0)["state"], "none")
            request.assert_not_called()

    def test_get_prefers_synced_lyrics(self):
        with patch.object(media, "request_json", return_value={"syncedLyrics": "[00:01]Hello", "plainLyrics": "Other"}):
            result = media.lyrics("Title", "Artist", "Album", 120)
        self.assertTrue(result["synced"])
        self.assertEqual(result["lines"][0]["text"], "Hello")

    def test_search_after_404_rejects_wrong_duration(self):
        candidates = [{"duration": 200, "plainLyrics": "Wrong"}, {"duration": 121, "plainLyrics": "Correct"}]
        with patch.object(media, "request_json", side_effect=[HTTPError("https://lrclib.net/", 404, "Missing", {}, None), candidates]):
            self.assertEqual(media.lyrics("Title", "Artist", "", 120)["lines"][0]["text"], "Correct")

    def test_redirect_does_not_send_metadata_to_other_sites(self):
        with self.assertRaises(URLError):
            media.LyricsRedirect().redirect_request(None, None, 302, "", {}, "https://example.com/")

    def test_video_metadata_recovers_artist_without_dropping_versions(self):
        self.assertEqual(media.clean_metadata("Artist - Song (Official Video)",""),("Song","Artist"))
        self.assertEqual(media.clean_metadata("Song (Live)","ArtistVEVO"),("Song (Live)","Artist"))

    def test_artistless_search_uses_title_and_rejects_unrelated_results(self):
        rows=[{"trackName":"Other song","artistName":"Other","duration":120,"plainLyrics":"Wrong"},
              {"trackName":"Known song","artistName":"Singer","duration":120,"plainLyrics":"Fixture lyrics"}]
        with patch.object(media,"request_json",return_value=rows) as request:
            self.assertEqual(media.lyrics("Known song","","",120)["lines"][0]["text"],"Fixture lyrics")
            request.assert_called_once_with("search",{"q":"Known song"})

    def test_cached_success_and_absence_do_not_query_again(self):
        with tempfile.TemporaryDirectory() as folder,patch.dict(os.environ,{"XDG_CACHE_HOME":folder}):
            for result in ({"state":"ok","lines":[{"t":0,"text":"Fixture"}],"synced":True},{"state":"none","lines":[],"synced":False}):
                with patch.object(media,"lyrics",return_value=result) as fetch:
                    title="Fixture "+result["state"]
                    self.assertEqual(media.cached_lyrics(title,"Artist","",120),result)
                    self.assertEqual(media.cached_lyrics(title,"Artist","",120),result)
                    fetch.assert_called_once()

    def test_offline_failure_has_a_short_cache_and_expired_results_retry(self):
        with tempfile.TemporaryDirectory() as folder,patch.dict(os.environ,{"XDG_CACHE_HOME":folder}),patch.object(media.time,"time",return_value=100):
            with patch.object(media,"lyrics",side_effect=URLError("Offline")) as fetch:
                self.assertEqual(media.cached_lyrics("Song","Artist","",120)["state"],"unavailable")
                media.cached_lyrics("Song","Artist","",120)
                fetch.assert_called_once()
            with patch.object(media.time,"time",return_value=161),patch.object(media,"lyrics",return_value={"state":"none","lines":[],"synced":False}) as fetch:
                media.cached_lyrics("Song","Artist","",120);fetch.assert_called_once()


if __name__ == "__main__":
    unittest.main()

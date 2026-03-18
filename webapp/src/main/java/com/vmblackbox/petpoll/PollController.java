package com.vmblackbox.petpoll;

import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;

/**
 * Handles all HTTP interactions for the pet name poll.
 *
 * <p>The application is deployed under the {@code /petpoll} context path (configured in
 * {@code application.properties}), so all mappings here are relative to that root.
 */
@Controller
public class PollController {

    private final JdbcTemplate jdbc;

    public PollController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /**
     * Displays the poll page with all pet names and their current vote counts,
     * ordered by vote count descending.
     */
    @GetMapping("/")
    public String poll(Model model) {
        List<PetVote> votes = jdbc.query(
                "SELECT pet_name, count FROM votes ORDER BY count DESC, pet_name ASC",
                (rs, rowNum) -> new PetVote(rs.getString("pet_name"), rs.getInt("count")));
        model.addAttribute("votes", votes);
        return "poll";
    }

    /**
     * Increments the vote count for the given pet name and redirects back to the poll page.
     *
     * @param petName the name of the pet to vote for (must already exist in the {@code votes} table)
     */
    @PostMapping("/vote")
    public String vote(@RequestParam String petName) {
        jdbc.update("UPDATE votes SET count = count + 1 WHERE pet_name = ?", petName);
        return "redirect:/";
    }
}
